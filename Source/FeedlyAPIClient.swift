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
import Box
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

    public static var sharedPipe: (ReactiveCocoa.Signal<AccountEvent, NSError>, SinkOf<ReactiveCocoa.Event<AccountEvent, NSError>>)! = Signal<AccountEvent, NSError>.pipe()

    public enum AccountEvent {
        case Login(Profile)
        case Logout
    }

    public class func handleError(#error:NSError) {
        if let dic = error.userInfo as NSDictionary? {
            if let response:NSHTTPURLResponse = dic[errorResponseKey] as? NSHTTPURLResponse {
                if response.statusCode == 401 {
                    if isLoggedIn { logout() }
                }
            }
        }
    }

    public class func alertController(#error:NSError, handler: (UIAlertAction!) -> Void) -> UIAlertController {
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
        sharedPipe.1.put(ReactiveCocoa.Event<AccountEvent, NSError>.Next(Box(AccountEvent.Login(profile))))
    }

    public class func logout() {
        _profile = nil
        setAccessToken("")
        sharedPipe.1.put(ReactiveCocoa.Event<AccountEvent, NSError>.Next(Box(AccountEvent.Logout)))
    }

    public var authUrl:  String {
        let url = String(format: "%@%@", target.baseUrl, CloudAPIClient.authPath)
        return url.stringByReplacingOccurrencesOfString("http",
                                           withString: "https",
                                              options: nil,
                                                range: nil)
    }
    public var tokenUrl: String { return String(format: "%@%@", target.baseUrl, CloudAPIClient.tokenPath) }

    public func buildError(error: NSError, response: NSHTTPURLResponse?) -> NSError {
        if let r = response {
            return NSError(domain: error.domain,
                            code: error.code,
                        userInfo: [CloudAPIClient.errorResponseKey: r])
        }
        return error
    }

    public func fetchProfile() -> SignalProducer<Profile, NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchProfile({ (req, res, profile, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    sink.put(Event.Next(Box(profile!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchSubscriptions() -> SignalProducer<[Subscription], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchSubscriptions({ (req, res, subscriptions, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    sink.put(.Next(Box(subscriptions!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchEntries(#streamId: String, newerThan: Int64, unreadOnly: Bool) -> SignalProducer<PaginatedEntryCollection, NSError> {
        var paginationParams        = PaginationParams()
        paginationParams.unreadOnly = unreadOnly
        paginationParams.count      = CloudAPIClient.perPage
        paginationParams.newerThan  = newerThan
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(#streamId: String, continuation: String?, unreadOnly: Bool) -> SignalProducer<PaginatedEntryCollection, NSError> {
        var paginationParams          = PaginationParams()
        paginationParams.unreadOnly   = unreadOnly
        paginationParams.count        = CloudAPIClient.perPage
        paginationParams.continuation = continuation
        return fetchEntries(streamId: streamId, paginationParams: paginationParams)
    }

    public func fetchEntries(#streamId: String, paginationParams: PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchContents(streamId, paginationParams: paginationParams, completionHandler: { (req, res, entries, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    sink.put(.Next(Box(entries!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchFeedsByIds(feedIds: [String]) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchFeeds(feedIds, completionHandler: { (req, res, feeds, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    sink.put(.Next(Box(feeds!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchCategories() -> SignalProducer<[FeedlyKit.Category], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.fetchCategories({ (req, res, categories, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    sink.put(.Next(Box(categories!)))
                    sink.put(.Completed)
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func searchFeeds(query: SearchQueryOfFeed) -> SignalProducer<[Feed], NSError> {
        return SignalProducer { (sink, disposable) in
            let req = self.searchFeeds(query, completionHandler: { (req, res, feedResults, error) -> Void in
                if let e = error {
                    sink.put(.Error(Box(self.buildError(e, response: res))))
                } else {
                    if let _feedResults = feedResults {
                        sink.put(.Next(Box(_feedResults.results)))
                        sink.put(.Completed)
                    }
                }
            })
            disposable.addDisposable({ req.cancel() })
        }
    }
}
