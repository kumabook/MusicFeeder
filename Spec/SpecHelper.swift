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
import Realm

open class Account {
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

open class SpecHelper {
    class var email:    String { return getAccount().email }
    class var password: String { return getAccount().password }
    
    open class func fixtureJSONObject(fixtureNamed: String) -> AnyObject? {
        let bundle   = Bundle(for: SpecHelper.self)
        let filePath = bundle.path(forResource: fixtureNamed, ofType: "json")
        let data     = try? Data(contentsOf: URL(fileURLWithPath: filePath!))
        let jsonObject : AnyObject? = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as AnyObject?
        return jsonObject
    }
    open class func getAccount() -> Account {
        let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "account")!)
        return Account(json: json)
    }

    open class func setupAPI() {
        CloudAPIClient.includesTrack = true
        let account = getAccount()
        let c = CloudAPIClient(target: CloudAPIClient.Target.custom(account.baseUrl))
        CloudAPIClient.clientId       = account.clientId
        CloudAPIClient.clientSecret   = account.clientSecret
        CloudAPIClient.sharedInstance = c
    }
    open class var api: CloudAPIClient { return CloudAPIClient.sharedInstance }
    open class func login() {
        setupAPI()
        api.fetchAccessToken(self.email, password: self.password, clientId: CloudAPIClient.clientId, clientSecret: CloudAPIClient.clientSecret)
            .on(value: {
                CloudAPIClient.setAccessToken($0.accessToken)
                api.fetchProfile().on(value: { CloudAPIClient._profile = $0 }).start()
            }).start()
    }
    open class func ping() {
        let account = getAccount()
        guard let url = URL(string: account.baseUrl) else {
            print("Error! Invalid URL!")
            return
        }
        
        let request = URLRequest(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { (_, _, _) -> Void in
            semaphore.signal()
        }.resume()
        let _ = semaphore.wait(timeout: .distantFuture)
    }
    open class func cleanRealmDBs() {
        removeFile(url: RLMRealmConfiguration.default().fileURL)
        removeFile(url: URL(string: "file://\(RealmMigration.historyPath)"))
        removeFile(url: URL(string: "file://\(RealmMigration.listenItLaterPath)"))
        removeFile(url: URL(string: "file://\(RealmMigration.cacheListPath)"))
        removeFile(url: URL(string: "file://\(RealmMigration.cacheSetPath)"))
    }
    private class func removeFile(url: URL?) {
        guard let url = url else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: url)
    }
}

extension Expectation {
    public func toFinally(_ predicate: Predicate<T>) {
        self.toEventually(predicate, timeout: 10)
    }
    
    public func toFinallyNot(_ predicate: Predicate<T>) {
        self.toEventuallyNot(predicate, timeout: 10)
    }
}
