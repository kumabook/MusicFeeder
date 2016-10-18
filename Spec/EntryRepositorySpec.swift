//
//  EntryRepositorySpec.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/17/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import MusicFeeder
import FeedlyKit
import Quick
import Nimble

class EntryRepositorySpec: QuickSpec {
    var entryRepository: EntryRepository!
    var stream: Feed = Feed(id: "feed/http://spincoaster.com/feed", title: "Spincoaster", description: "", subscribers: 0)
    override func spec() {
        describe("A EntryRepository") {
            var started = false
            var completed = false
            beforeSuite {
                CloudAPIClient.sharedInstance = SpecHelper.api
                SpecHelper.login()
                EntryCacheList.deleteAllItems()
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
                    print(self.entryRepository.items.count)
                }
            }
            context("when it has cache") {
                beforeEach {
                    self.entryRepository = EntryRepository(stream: self.stream, unreadOnly: false, perPage: 20, needsPlaylist: false)
                }
                it("fetches entries from cache") {
                    expect(self.entryRepository.items.count).to(beGreaterThan(0))
                    print(self.entryRepository.items.count)
                    print("-----------")
                }
            }
        }
    }
}