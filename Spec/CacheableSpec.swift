//
//  CacheableSpec.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/01/12.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Quick
import Nimble
import MusicFeeder

class CacheableSpec: QuickSpec {
    var tracks: [Track] = []
    override func spec() {
        beforeEach {
            self.tracks = (0..<50).map { Track(id: "track_\($0)", provider: Provider.YouTube, url: "https://test.com", identifier: "\($0)", title: "track_\($0)" ) }
        }
        afterEach {
            TrackCacheList.deleteAllItems()
        }
        describe("CacheList") {
            describe("deleteAllItems") {
                it ("should delete all cache items") {
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).to(equal(0))
                    let _ = TrackCacheList.findOrCreate("test_cache").add(self.tracks)
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).notTo(equal(0))
                    TrackCacheList.deleteAllItems()
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).to(equal(0))
                }
            }
            describe("deleteOldItems") {
                it ("should delete old cache items before the specified date") {
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).to(equal(0))
                    let _ = TrackCacheList.findOrCreate("test_cache").add(self.tracks)
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).notTo(equal(0))
                    TrackCacheList.deleteOldItems(before: Date().timestamp + 1000)
                    expect(TrackCacheList.findOrCreate("test_cache").items.count).to(equal(0))
                }
            }

        }
        describe("CacheSet") {
            describe("deleteAllItems") {
                it ("should delete all cache items") {
                    expect(TrackCacheSet.getAllItems().count).to(equal(0))
                    let _ = TrackCacheSet.set(self.tracks[0].id, item: self.tracks[0])
                    expect(TrackCacheSet.getAllItems().count).notTo(equal(0))
                    TrackCacheSet.deleteAllItems()
                    expect(TrackCacheSet.getAllItems().count).to(equal(0))
                }
            }
            describe("deleteOldItems") {
                it ("should delete old cache items before the specified date") {
                    expect(TrackCacheSet.getAllItems().count).to(equal(0))
                    let _ = TrackCacheSet.set(self.tracks[0].id, item: self.tracks[0])
                    expect(TrackCacheSet.getAllItems().count).notTo(equal(0))
                    TrackCacheSet.deleteOldItems(before: Date().timestamp + 1000)
                    expect(TrackCacheSet.getAllItems().count).to(equal(0))
                }
            }
        }
    }
}
