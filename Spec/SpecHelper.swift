//
//  SpecHelper.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/25/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Nimble
import FeedlyKit
import MusicFeeder
import SwiftyJSON

public class Account {
    var baseUrl:      String
    var clientId:     String
    var clientSecret: String
    var email:        String
    var password:     String
    public init(json: JSON) {
        baseUrl      = json["baseUrl"].stringValue
        clientId     = json["clientId"].stringValue
        clientSecret = json["clientSecret"].stringValue
        email        = json["email"].stringValue
        password     = json["password"].stringValue
    }
}

public class SpecHelper {
    class var email:    String { return getAccount().email }
    class var password: String { return getAccount().password }
    
    public class func fixtureJSONObject(fixtureNamed fixtureNamed: String) -> AnyObject? {
        let bundle   = NSBundle(forClass: SpecHelper.self)
        let filePath = bundle.pathForResource(fixtureNamed, ofType: "json")
        let data     = NSData(contentsOfFile: filePath!)
        let jsonObject : AnyObject? = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
        return jsonObject
    }
    public class func getAccount() -> Account {
        let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "account")!)
        return Account(json: json)
    }

    public class func setupAPI() {
        CloudAPIClient.includesTrack = true
        let account = getAccount()
        let c = CloudAPIClient(target: CloudAPIClient.Target.Custom(account.baseUrl))
        CloudAPIClient.clientId       = account.clientId
        CloudAPIClient.clientSecret   = account.clientSecret
        CloudAPIClient.sharedInstance = c
    }
    public class var api: CloudAPIClient { return CloudAPIClient.sharedInstance }
    public class func login() {
        setupAPI()
        api.fetchAccessToken(self.email, password: self.password, clientId: CloudAPIClient.clientId, clientSecret: CloudAPIClient.clientSecret)
            .on(next: {
                CloudAPIClient.setAccessToken($0.accessToken)
                api.fetchProfile().on(next: { CloudAPIClient._profile = $0 }).start()
            }).start()
    }
}

extension Expectation {
    public func toFinally<U where U : Matcher, U.ValueType == T>(matcher: U) {
        self.toEventually(matcher, timeout: 10)
    }
    
    public func toFinallyNot<U where U : Matcher, U.ValueType == T>(matcher: U) {
        self.toEventuallyNot(matcher, timeout: 10)
    }
}
