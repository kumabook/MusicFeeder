//
//  FeedlyAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/21/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa
import Result
import FeedlyKit
import Alamofire

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

    public static var sharedInstance: CloudAPIClient = CloudAPIClient(target: Target.Sandbox)
    static let errorResponseKey = "com.alamofire.serialization.response.error.response"

    public static var _profile: Profile?
    public static var profile: Profile? { return _profile }

    public static var sharedPipe: (Signal<AccountEvent, NSError>, Signal<AccountEvent, NSError>.Observer)! = Signal<AccountEvent, NSError>.pipe()

    public enum AccountEvent {
        case Login(Profile)
        case Logout
    }

    public class func handleError(error error:ErrorType) {
        let e = error as NSError
        if let dic = e.userInfo as NSDictionary? {
            if let response:NSHTTPURLResponse = dic[errorResponseKey] as? NSHTTPURLResponse {
                if response.statusCode == 401 {
                    if isLoggedIn { logout() }
                }
            }
        }
    }

    public class func alertController(error error:ErrorType, handler: (UIAlertAction!) -> Void) -> UIAlertController {
        let ac = UIAlertController(title: "Network error".localize(),
            message: "Sorry, network error occured.".localize(),
            preferredStyle: UIAlertControllerStyle.Alert)
        let okAction = UIAlertAction(title: "OK".localize(), style: UIAlertActionStyle.Default, handler: handler)
        ac.addAction(okAction)
        return ac
    }

   public class func setAccessToken(token: String) {
        CloudAPIClient.sharedInstance.setAccessToken(token)
    }

    public class var isLoggedIn: Bool {
        return _profile != nil
    }

    public class func login(profile: Profile, token: String) {
        _profile = profile
        setAccessToken(token)
        sharedPipe.1.sendNext(AccountEvent.Login(profile))
    }

    public class func logout() {
        _profile = nil
        setAccessToken("")
        sharedPipe.1.sendNext(AccountEvent.Logout)
    }

    public var authUrl:  String {
        let url = String(format: "%@%@", target.baseUrl, CloudAPIClient.authPath)
        return url.stringByReplacingOccurrencesOfString("http",
                                           withString: "https",
                                              options: [],
                                                range: nil)
    }
    public var tokenUrl: String { return String(format: "%@%@", target.baseUrl, CloudAPIClient.tokenPath) }

    public func buildError(error: ErrorType, response: NSHTTPURLResponse?) -> NSError {
        if let r = response {
            return NSError(domain: error._domain,
                            code: error._code,
                        userInfo: [CloudAPIClient.errorResponseKey: r])
        }
        return error as NSError
    }

    public func fetchProfile() -> SignalProducer<Profile, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchProfile({ response -> Void in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else if let profile = response.result.value {
                    observer.sendNext(profile)
                    observer.sendCompleted()
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchSubscriptions() -> SignalProducer<[Subscription], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchSubscriptions({ response in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else if let subscriptions = response.result.value {
                    observer.sendNext(subscriptions)
                    observer.sendCompleted()
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchEntries(streamId streamId: String, newerThan: Int64, unreadOnly: Bool, perPage: Int) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let paginationParams        = PaginationParams()
        paginationParams.unreadOnly = unreadOnly
        paginationParams.count      = perPage
        paginationParams.newerThan  = newerThan
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(streamId streamId: String, continuation: String?, unreadOnly: Bool, perPage: Int) -> SignalProducer<PaginatedEntryCollection, NSError> {
        let paginationParams          = PaginationParams()
        paginationParams.unreadOnly   = unreadOnly
        paginationParams.count        = perPage
        paginationParams.continuation = continuation
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(streamId streamId: String, paginationParams: PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchContents(streamId, paginationParams: paginationParams, completionHandler: { response in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else if let entries = response.result.value {
                    observer.sendNext(entries)
                    observer.sendCompleted()
                } else {
                    observer.sendFailed(self.buildError(NSError(domain: "MusicFeeder", code: 0, userInfo: [:]), response: response.response))
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchFeedsByIds(feedIds: [String]) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchFeeds(feedIds, completionHandler: { response in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else if let feeds = response.result.value {
                    observer.sendNext(feeds)
                    observer.sendCompleted()
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchCategories() -> SignalProducer<[FeedlyKit.Category], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.fetchCategories({ response in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else if let categories = response.result.value {
                    observer.sendNext(categories)
                    observer.sendCompleted()
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func searchFeeds(query: SearchQueryOfFeed) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (observer, disposable) in
            let req = self.searchFeeds(query, completionHandler: { response in
                if let e = response.result.error {
                    observer.sendFailed(self.buildError(e, response: response.response))
                } else {
                    if let feedResults = response.result.value {
                        observer.sendNext(feedResults.results)
                        observer.sendCompleted()
                    }
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }
}
