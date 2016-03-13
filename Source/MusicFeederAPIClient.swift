//
//  MusicFeederAPIClient.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/13/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveCocoa
import Alamofire
import SwiftyJSON

public struct AccessToken: ResponseObjectSerializable {
    public var accessToken: String
    public var tokenType:   String
    public var createdAt:   Int64
    public init?(response: NSHTTPURLResponse, representation: AnyObject) {
        let json = JSON(representation)
        self.init(json: json)
    }

    init(json: JSON) {
        self.accessToken = json["access_token"].stringValue
        self.tokenType   = json["token_type"].stringValue
        self.createdAt   = json["created_at"].int64Value
    }
}

struct CreateProfileAPI: API {
    var email:      String
    var password:   String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/profile" }
    var method:     Alamofire.Method { return .PUT }
    var URLRequest: NSMutableURLRequest {
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: ["email": email, "password": password, "password_confirmation": password]).0
    }
}

struct FetchAccessTokenAPI: API {
    var email:      String
    var password:   String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/oauth/token" }
    var method:     Alamofire.Method { return .POST }
    var URLRequest: NSMutableURLRequest {
        let params = ["grant_type": "password",
                       "client_id": CloudAPIClient.clientId,
                   "client_secret": CloudAPIClient.clientSecret,
                           "email": email,
                        "password": password]
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: params).0
    }
}


extension CloudAPIClient {
    public func createProfile(email: String, password: String) -> SignalProducer<Profile, NSError> {
        let route = Router.Api(CreateProfileAPI(email: email, password: password))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<Profile, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let profile = r.result.value {
                    observer.sendNext(profile)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchAccessToken(email: String, password: String) -> SignalProducer<AccessToken, NSError> {
        let route = Router.Api(FetchAccessTokenAPI(email: email, password: password))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<AccessToken, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let accessToken = r.result.value {
                    observer.sendNext(accessToken)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }
}