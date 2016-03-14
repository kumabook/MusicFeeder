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
import ReactiveCocoa

class FeedlyAPISpec: QuickSpec {
    let uuid:     String = NSUUID().UUIDString
    var email:    String { return "test-\(uuid)" }
    var password: String { return "password-\(uuid)" }

    var accessToken: MusicFeeder.AccessToken?

    var profile: Profile?
    var feeds:   [Feed]?
    var entries: [Entry]?
    var tracks:  [Track]?

    var client: CloudAPIClient {
        let c = CloudAPIClient.sharedInstance
        c.setAccessToken(self.accessToken?.accessToken)
        return c
    }


    override func spec() {
        describe("PUT /v3/profile") {
            beforeEach {
                self.client.createProfile(self.email, password: self.password)
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

        describe("POST /v3/oauth/token") {
            beforeEach {
                self.client.fetchAccessToken(self.email, password: self.password, clientId: CloudAPIClient.clientId, clientSecret: CloudAPIClient.clientSecret)
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
                self.client.fetchProfile()
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

        describe("GET /v3/search/feeds") {
            beforeEach {
                self.client.searchFeeds(SearchQueryOfFeed(query: ""))
                    .on(next: {
                        self.feeds = $0
                    }).start()
            }
            it("should fetch a user") {
                expect(self.feeds).toEventuallyNot(beNil())
                expect(self.feeds!.count).to(beGreaterThan(0))
            }
        }

        describe("GET /v3/streams/:streamId/contents") {
            beforeEach {
                self.client.fetchEntries(streamId: self.feeds![0].id, paginationParams: PaginationParams())
                    .on(next: {
                        self.entries = $0.items
                    }).start()
            }
            it("should fetch a user") {
                expect(self.entries).toEventuallyNot(beNil())
                expect(self.entries!.count).to(beGreaterThan(0))
                expect(self.entries![0].engagement).notTo(beNil())
                expect(self.entries![0].enclosure).notTo(beNil())

                for e in self.entries! {
                    for enc in e.enclosure! {
                        expect(enc.type).notTo(beNil())
                        expect(enc.href).notTo(beNil())
                    }
                }

                self.tracks = self.entries.flatMap { $0.map { $0.tracks }.flatMap { $0 } }.map { Array($0.prefix(1)) }
                for t in self.tracks! {
                    expect(t.id).notTo(beNil())
                    expect(t.likesCount).to(beNil())
                    expect(t.likers).to(beNil())
                }
            }
        }

        describe("POST /v3/markers") {
            var isFinish = false
            var oldLikesCount: Int64 = 0
            var newLikesCount: Int64 = 0
            beforeEach {
                guard let ts = self.tracks else { return }
                let track = ts[0]
                self.client.markTracksAsUnliked(ts).flatMap(.Concat) {
                    self.client.fetchTracks([track.id])
                }.flatMap(.Concat) { (tracks: [Track]) -> SignalProducer<Void, NSError> in
                    oldLikesCount = tracks[0].likesCount!
                    return self.client.markTracksAsLiked(ts)
                }.flatMap(.Concat) {(_: ()) -> SignalProducer<[Track], NSError> in
                    self.client.fetchTracks([track.id])
                }.on(next: { tracks in
                    newLikesCount = tracks[0].likesCount!
                }, disposed: {
                    isFinish = true
                }).start()
            }
            it("should fetch a user") {
                expect(isFinish).toEventually(equal(true), timeout: 30)
                expect(self.tracks).toEventuallyNot(beNil())
                expect(newLikesCount).to(equal(oldLikesCount + 1))
            }
        }

        describe("GET /v3/tracks/:id") {
            var track: Track?
            beforeEach {
                self.client.fetchTrack(self.tracks![0].id)
                    .on(next: {
                        track = $0
                    }).start()
            }
            it("should fetch a track") {
                expect(track).toEventuallyNot(beNil())
                expect(track!.likesCount).notTo(beNil())
                expect(track!.likers).notTo(beNil())
            }
        }

        describe("POST /v3/tracks/.mget") {
            var tracks: [Track]?
            beforeEach {
                self.client.fetchTracks(self.tracks!.map { $0.id })
                    .on(next: {
                        tracks = $0
                    }).start()
            }
            it("should fetch a track") {
                expect(tracks).toEventuallyNot(beNil())
                expect(tracks!.count).to(equal(self.tracks!.count))
                for track in tracks! {
                    expect(track.likesCount).notTo(beNil())
                    expect(track.likers).notTo(beNil())
                }
            }
        }
    }
}
