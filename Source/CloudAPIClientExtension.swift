//
//  CloudAPIClientExtension.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2016 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveSwift
import Result
import FeedlyKit
import Alamofire
import Cache
#if os(iOS)
    import UIKit
#endif

extension CloudAPIClient {
    public static var perPage       = 15
    public static var clientId      = "sandbox"
    public static var clientSecret  = ""
    public static let authPath      = "/v3/auth/auth"
    public static let tokenPath     = "/v3/auth/token"
    public static let accountType   = "Feedly"
    public static let redirectUrl   = "http://localhost"
    public static let scope         = Set(["https://cloud.feedly.com/subscriptions"])
    public static let keyChainGroup = "Feedly"
    public static var includesTrack = false

    public static var shared: CloudAPIClient = CloudAPIClient(target: Target.sandbox)
    static let errorResponseKey = "com.alamofire.serialization.response.error.response"

    public static var _profile: Profile?
    public static var profile: Profile? { return _profile }

    public static var sharedPipe: (Signal<AccountEvent, NSError>, Signal<AccountEvent, NSError>.Observer)! = Signal<AccountEvent, NSError>.pipe()

    public enum AccountEvent {
        case Login(Profile)
        case Logout
    }

    public class func handleError(error: Error) {
        let e = error as NSError
        if let response:HTTPURLResponse = e.userInfo[errorResponseKey] as? HTTPURLResponse {
            if response.statusCode == 401 {
                if isLoggedIn { logout() }
             }
        }
    }

    #if os(iOS)
    public class func alertController(error:Error, handler: @escaping (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: "Network error".localize(),
            message: "Sorry, network error occured.".localize(),
            preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.default, handler: handler)
        ac.addAction(okAction)
        return ac
    }
    #endif

    public func updateAccessToken(_ token: String) {
        setAccessToken(token)
        manager.adapter = ApiRequestAdapter(apiVersion: "1", accessToken: token)
    }

    public class var isLoggedIn: Bool {
        return _profile != nil
    }

    public class func login(profile: Profile, token: String) {
        _profile = profile
        shared.updateAccessToken(token)
        sharedPipe.1.send(value: AccountEvent.Login(profile))
    }

    public class func logout() {
        _profile = nil
        shared.setAccessToken("")
        shared.manager.adapter = ApiRequestAdapter(apiVersion: "1", accessToken: nil)
        sharedPipe.1.send(value: AccountEvent.Logout)
    }

    public var authUrl:  String {
        let url = String(format: "%@%@", target.baseUrl, CloudAPIClient.authPath)
        return url.replace("http", withString: "https")
    }
    public var tokenUrl: String { return String(format: "%@%@", target.baseUrl, CloudAPIClient.tokenPath) }

    public func buildError(error: NSError, response: HTTPURLResponse?) -> NSError {
        if let r = response {
            return NSError(domain: error._domain,
                            code: error._code,
                        userInfo: [CloudAPIClient.errorResponseKey: r])
        }
        return error
    }

    public func fetchProfile() -> SignalProducer<Profile, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchProfile({ response -> Void in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let profile = response.result.value {
                    observer.send(value: profile)
                    observer.sendCompleted()
                }
            })
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func updateProfile(params: [String:Any]) -> SignalProducer<Profile, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.updateProfile(params) { response -> Void in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let profile = response.result.value {
                    observer.send(value: profile)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchFeed(feedId: String) -> SignalProducer<Feed, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchFeed(feedId, completionHandler: { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let feed = response.result.value {
                    observer.send(value: feed)
                    observer.sendCompleted()
                } else {
                    observer.send(error: self.buildError(error: NSError(domain: "MusicFeeder", code: 0, userInfo: [:]), response: response.response))
                }
            })
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchSubscriptions() -> SignalProducer<[Subscription], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchSubscriptions({ response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let subscriptions = response.result.value {
                    observer.send(value: subscriptions)
                    observer.sendCompleted()
                }
            })
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchEntries(streamId: String, newerThan: Int64, unreadOnly: Bool, perPage: Int) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let paginationParams        = PaginationParams()
        paginationParams.unreadOnly = unreadOnly
        paginationParams.count      = perPage
        paginationParams.newerThan  = newerThan
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(streamId: String, continuation: String?, unreadOnly: Bool, perPage: Int) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let paginationParams          = PaginationParams()
        paginationParams.unreadOnly   = unreadOnly
        paginationParams.count        = perPage
        paginationParams.continuation = continuation
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let route = Router.fetchContents(target, streamId, paginationParams)
        return SignalProducer { (observer, disposable) in
            if useCache {
                if let url = route.urlRequest?.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let v = PaginatedEntryCollection(json: JSON(parseJSON: json))
                    observer.send(value: v)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).validate().responseJSON() { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let value = response.result.value {
                    let json = JSON(value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    observer.send(value: PaginatedEntryCollection(json: json))
                    observer.sendCompleted()
                } else {
                    observer.send(error: self.buildError(error: NSError(domain: "MusicFeeder", code: 0, userInfo: [:]), response: response.response))
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchMix(streamId: String, paginationParams: MixParams, useCache: Bool = false) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let route = Router.fetchMix(target, streamId, paginationParams)
        return SignalProducer { (observer, disposable) in
            if useCache {
                if let url = route.urlRequest?.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let v = PaginatedEntryCollection(json: JSON(parseJSON: json))
                    observer.send(value: v)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).validate().responseJSON() { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let value = response.result.value {
                    let json = JSON(value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    observer.send(value: PaginatedEntryCollection(json: json))
                    observer.sendCompleted()
                } else {
                    observer.send(error: self.buildError(error: NSError(domain: "MusicFeeder", code: 0, userInfo: [:]), response: response.response))
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchFeedsByIds(feedIds: [String]) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchFeeds(feedIds, completionHandler: { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let feeds = response.result.value {
                    observer.send(value: feeds)
                    observer.sendCompleted()
                }
            })
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchCategories() -> SignalProducer<[FeedlyKit.Category], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchCategories({ response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let categories = response.result.value {
                    observer.send(value: categories)
                    observer.sendCompleted()
                }
            })
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func searchFeeds(query: SearchQueryOfFeed, useCache: Bool = false) -> SignalProducer<[Feed], NSError> {
        let route = Router.searchFeeds(target, query)
        return SignalProducer { (observer, disposable) in
            if useCache {
                if let url = route.urlRequest?.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let feeds = JSON(parseJSON: json).arrayValue.map({ Feed(json: $0) })
                    observer.send(value: feeds)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).responseJSON() {response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let value = response.result.value {
                    let json = JSON(value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    let feedResults = SearchResultFeeds(json: json)
                    observer.send(value: feedResults.results)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchEntry(entryId: String) -> SignalProducer<FeedlyKit.Entry, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchEntry(entryId) { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else {
                    if let entry = response.result.value {
                        observer.send(value: entry)
                        observer.sendCompleted()
                    }
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchEntries(entryIds: [String]) -> SignalProducer<[FeedlyKit.Entry], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchEntries(entryIds) { response in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else {
                    if let entries = response.result.value {
                        observer.send(value: entries)
                        observer.sendCompleted()
                    }
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func markEntriesAsSaved(itemIds: [String]) -> SignalProducer<Void, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.markEntriesAsSaved(itemIds) { response in
                if let e = response.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func markEntriesAsUnsaved(itemIds: [String]) -> SignalProducer<Void, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.markEntriesAsUnsaved(itemIds) { response in
                if let e = response.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

}
