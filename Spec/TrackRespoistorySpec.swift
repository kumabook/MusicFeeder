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
                CloudAPIClient.shared = SpecHelper.api
                SpecHelper.login()
                JSONCache.shared.clear()
            }
            context("1 when it has no cache") {
                beforeEach {
                    expect(CloudAPIClient.isLoggedIn).toFinally(beTrue())
                    started = false
                    completed = false
                    self.entryRepository = EntryRepository(stream: self.stream, unreadOnly: false, perPage: 20)
                    self.entryRepository.signal.observeResult({ result in
                        guard let event = result.value else { return }
                        switch event {
                        case .startLoadingNext:
                            started = true
                            break
                        case .completeLoadingNext:
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
                    expect(self.entryRepository.getItems().count).toFinally(beGreaterThan(0))
                    let entry = self.entryRepository.getItems()[0]
                    expect(entry.tracks.count).to(beGreaterThan(0))
                    let track = entry.tracks[0]
                    if track.status == .loading {
                        expect(track.status).to(equal(Track.Status.loading))
                        expect(track.isLiked).to(beNil())
                        expect(track.isPlayed).to(beNil())
                    } else {
                        expect(track.status).toFinally(equal(Track.Status.available))
                    }
                }
            }
            context("2 when it has cache") {
                beforeEach {
                    self.entryRepository = EntryRepository(stream: self.stream, unreadOnly: false, perPage: 20)
                }
                it("fetches entries from cache") {
                    expect(self.entryRepository.state).toFinally(equal(PaginatedCollectionRepositoryState.init))
                    self.entryRepository.fetchCacheItems()
                    expect(self.entryRepository.state).toFinally(equal(PaginatedCollectionRepositoryState.cacheOnly))
                    expect(self.entryRepository.getItems().count).to(beGreaterThan(0))
                    if self.entryRepository.getItems().count > 0 {
                        let entry = self.entryRepository.getItems()[0]
                        expect(entry.tracks.count).to(beGreaterThan(0))
                        if let track = entry.tracks.get(0) {
                            expect(track.status).toFinally(equal(Track.Status.init))
                            expect(track.entries).to(beNil())
                            expect(track.title?.count ?? 0).to(beGreaterThan(0))
                            expect(track.thumbnailUrl).notTo(beNil())
                        }
                    }
                }
            }
        }
    }
}
