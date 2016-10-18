//
//  TrackRespoistorySpec.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/18/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import MusicFeeder
import FeedlyKit
import Quick
import Nimble

class TrackRespoistorySpec: QuickSpec {
    var entryRepository: EntryRepository!
    var stream: Feed = Feed(id: "feed/http://spincoaster.com/feed", title: "Spincoaster", description: "", subscribers: 0)

    override func spec() {
        describe("A TrackRepository") {
            var started = false
            var completed = false
            beforeSuite {
                CloudAPIClient.sharedInstance = SpecHelper.api
                SpecHelper.login()
                EntryCacheList.deleteAllItems()
                TrackCacheMap.deleteAllItems()
            }
            context("when it has no cache") {
                beforeEach {
                    expect(CloudAPIClient.isLoggedIn).toFinally(beTrue())
                    started = false
                    completed = false
                    self.entryRepository = EntryRepository(stream: self.stream, unreadOnly: false, perPage: 20, needsPlaylist: false)
                    self.entryRepository.signal.observeNext({ event in
                        switch event {
                        case .StartLoadingNext:
                            started = true
                            break
                        case .CompleteLoadingNext:
                            completed = true
                            break
                        default:
                            break
                        }
                    })
                    self.entryRepository.fetchItems()
                }
                it("fetches entries from server") {
                    expect(started).toFinally(beTrue())
                    expect(completed).toFinally(beTrue())
                    expect(self.entryRepository.items.count).toFinally(beGreaterThan(0))
                    let entry = self.entryRepository.items[0]
                    expect(entry.tracks.count).to(beGreaterThan(0))
                    let track = entry.tracks[0]
                    expect(track.status).to(equal(Track.Status.Loading))
                    expect(track.title!.characters.count).to(equal(0))
                    expect(track.thumbnailUrl).to(beNil())

                    expect(track.status).toFinally(equal(Track.Status.Available))
                    expect(track.title!.characters.count).to(beGreaterThan(0))
                    expect(track.thumbnailUrl).notTo(beNil())
                }
            }
            context("when it has cache") {
                beforeEach {
                    self.entryRepository = EntryRepository(stream: self.stream, unreadOnly: false, perPage: 20, needsPlaylist: false)
                }
                it("fetches entries from cache") {
                    expect(self.entryRepository.items.count).to(beGreaterThan(0))
                    let entry = self.entryRepository.items[0]
                    expect(entry.tracks.count).to(beGreaterThan(0))
                    let track = entry.tracks[0]
                    expect(track.status).to(equal(Track.Status.Loading))
                    expect(track.title!.characters.count).to(beGreaterThan(0))
                    expect(track.thumbnailUrl).notTo(beNil())
                }
            }
        }
    }
}
