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
import ReactiveSwift

class FeedlyAPISpec: QuickSpec {
    let uuid:     String = NSUUID().uuidString
    var email:    String { return "test-\(uuid)" }
    var password: String { return "password-\(uuid)" }

    var accessToken: MusicFeeder.AccessToken?

    var profile: Profile?
    var feeds:   [Feed]?
    var entries: [Entry]?
    var tracks:  [Track]?

    var client: CloudAPIClient {
        return CloudAPIClient.shared
    }

    override func spec() {
        beforeSuite {
            SpecHelper.setupAPI()
        }
        beforeEach {
            if let token = self.accessToken?.accessToken {
                self.client.updateAccessToken(token)
            }
        }
        describe("PUT /v3/profile") {
            beforeEach {
                self.client.createProfile(self.email, password: self.password)
                    .on(value: {
                       self.profile = $0
                    }).start()
            }
            it("should create a user") {
                expect(self.profile).toFinallyNot(beNil())
                expect(self.profile!.email!).to(equal(self.email))
                expect(self.profile!.id).notTo(beNil())
            }
        }

        describe("POST /v3/oauth/token") {
            beforeEach {
                self.client.fetchAccessToken(self.email, password: self.password, clientId: CloudAPIClient.clientId, clientSecret: CloudAPIClient.clientSecret)
                    .on(failed: {
                        print("error \($0.code)")
                    }, value: {
                        self.accessToken = $0
                    }).start()
            }
            it("should fetch accessToken") {
                expect(self.accessToken).toFinallyNot(beNil())
            }
        }

        describe("GET /v3/profile") {
            var _profile: Profile?
            beforeEach {
                self.client.fetchProfile()
                    .on(value: {
                        _profile = $0
                    }).start()
            }
            it("should fetch a user") {
                expect(_profile).toFinallyNot(beNil())
                if let p = _profile {
                    expect(p.id).to(equal(self.profile!.id))
                    expect(p.email!).to(equal(self.profile!.email))
                }
            }
        }

        describe("GET /v3/search/feeds") {
            beforeEach {
                self.client.searchFeeds(query: SearchQueryOfFeed(query: ""))
                    .on(value: {
                        self.feeds = $0
                    }).start()
            }
            it("should fetch a user") {
                expect(self.feeds).toFinallyNot(beNil())
                expect(self.feeds!.count).to(beGreaterThan(0))
            }
        }

        describe("GET /v3/streams/:streamId/contents") {
            beforeEach {
                guard let feed = self.feeds?[0] else { return }
                self.client.fetchEntries(streamId: feed.id, paginationParams: MusicFeeder.PaginationParams())
                    .on(value: {
                        self.entries = $0.items
                    }).start()
                return
            }
            it("should fetch entries") {
                expect(self.entries).toFinallyNot(beNil())
                guard let entries = self.entries else { return }
                expect(entries.count).to(beGreaterThan(0))
                expect(entries[0].engagement).notTo(beNil())
                expect(entries[0].enclosure).notTo(beNil())

                for e in entries {
                    for enc in e.enclosure! {
                        expect(enc.type).notTo(beNil())
                        expect(enc.href).notTo(beNil())
                    }
                }

                self.tracks = entries.map { $0.tracks }.flatMap { Array($0.prefix(1)) }
                for t in self.tracks! {
                    expect(t.id).notTo(beNil())
                    expect(t.likesCount).notTo(beNil())
                    expect(t.likers).to(beNil())
                }
            }
        }

        describe("POST /v3/markers") {
            var isFinish = false
            var oldLikesCount: Int64 = 0
            var track: Track?
            beforeEach {
                guard let ts = self.tracks else { return }
                track = ts[0]
                self.client.markTracksAs(.unliked, items: ts).flatMap(.concat) {
                    self.client.fetchTracks([track!.id])
                }.flatMap(.concat) { (tracks: [Track]) -> SignalProducer<Void, NSError> in
                    oldLikesCount = tracks[0].likesCount!
                    return self.client.markTracksAs(.liked, items: ts)
                }.flatMap(.concat) {(_: ()) -> SignalProducer<[Track], NSError> in
                    self.client.fetchTracks([track!.id])
                }.on(disposed: {
                    isFinish = true
                }, value: { tracks in
                    track         = tracks[0]
                }).start()
            }
            it("should mark as liked") {
                expect(isFinish).toFinally(equal(true))
                expect(self.tracks).toFinallyNot(beNil())
                expect(track!.isLiked).to(beTrue())
                expect(track!.likesCount).to(equal(oldLikesCount + 1))
            }
        }

        describe("GET /v3/tracks/:id") {
            var track: Track?
            beforeEach {
                self.client.fetchTrack(self.tracks![0].id)
                    .on(value: {
                        track = $0
                    }).start()
            }
            it("should fetch a track") {
                expect(track).toFinallyNot(beNil())
                expect(track!.likesCount).notTo(beNil())
            }
        }

        describe("POST /v3/tracks/.mget") {
            var tracks: [Track]?
            var ids: [String] = []
            beforeEach {
                ids = self.tracks!.map { $0.id }.unique
                self.client.fetchTracks(ids)
                    .on(value: {
                        tracks = $0
                    }).start()
            }
            it("should fetch a track") {
                expect(tracks).toFinallyNot(beNil())

                expect(tracks!.count).to(equal(ids.count))
                for track in tracks! {
                    expect(track.likesCount).notTo(beNil())
                }
            }
        }
    }
}
