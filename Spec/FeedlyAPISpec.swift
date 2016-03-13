//
//  ProfileAPISpec.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/13/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import MusicFeeder
import FeedlyKit
import SwiftyJSON
import Quick
import Nimble

class FeedlyAPISpec: QuickSpec {
    let uuid:     String = NSUUID().UUIDString
    var email:    String { return "test-\(uuid)" }
    var password: String { return "password-\(uuid)" }

    var profile:     Profile?
    var accessToken: MusicFeeder.AccessToken?


    override func spec() {
        describe("PUT /v3/profile") {
            beforeEach {
                let client = CloudAPIClient.sharedInstance
                client.createProfile(self.email, password: self.password)
                    .on(next: {
                       self.profile = $0
                    }).start()
            }
            it("should create a user") {
                expect(self.profile).toEventuallyNot(beNil())
                expect(self.profile!.email!).to(equal(self.email))
                expect(self.profile!.id).notTo(beNil())
            }
        }

        describe("POST /oauth/token") {
            beforeEach {
                let client = CloudAPIClient.sharedInstance
                client.fetchAccessToken(self.email, password: self.password)
                    .on(failed: {
                            print("error \($0.code)")
                        }, next: {
                            self.accessToken = $0
                    }).start()
            }
            it("should fetch accessToken") {
                expect(self.accessToken).toEventuallyNot(beNil())
            }
        }

        describe("GET /v3/profile") {
            var _profile: Profile?
            beforeEach {
                let client = CloudAPIClient.sharedInstance
                client.setAccessToken(self.accessToken!.accessToken)
                client.fetchProfile()
                    .on(next: {
                        _profile = $0
                    }).start()
            }
            it("should fetch a user") {
                expect(_profile).toEventuallyNot(beNil())
                expect(_profile!.id).to(equal(self.profile!.id))
                expect(_profile!.email!).to(equal(self.profile!.email))
            }
        }
    }
}
