//
//  TopicRepositorySpec.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/12/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import MusicFeeder
import FeedlyKit
import Quick
import Nimble

class TopicRepositorySpec: QuickSpec {
    var topicRepository: TopicRepository!
    override func spec() {
        describe("A TopicRepository") {
            var started = false
            var completed = false
            beforeSuite {
                CloudAPIClient.sharedInstance = SpecHelper.api
                SpecHelper.login()
                TopicCacheList.deleteAllItems()
            }
            context("when it has no cache") {
                beforeEach {
                    expect(CloudAPIClient.isLoggedIn).toFinally(beTrue())
                    started = false
                    completed = false
                    self.topicRepository = TopicRepository(cloudApiClient: CloudAPIClient.sharedInstance)
                    self.topicRepository.signal.observeNext({ event in
                        switch event {
                        case .StartLoading:
                            started = true
                        case .CompleteLoading:
                            completed = true
                        default:
                            break
                        }
                    })
                    self.topicRepository.fetch()
                }
                it("fetches topics from server") {
                    expect(started).toFinally(beTrue())
                    expect(completed).toFinally(beTrue())
                    expect(self.topicRepository.items.count).toFinally(beGreaterThan(0))
                }
            }
            context("when it has cache") {
                beforeEach {
                    self.topicRepository = TopicRepository(cloudApiClient: CloudAPIClient.sharedInstance)
                }
                it("fetches topics from cache") {
                    expect(self.topicRepository.getItems().count).to(beGreaterThan(0))
                }
            }
        }
    }
}