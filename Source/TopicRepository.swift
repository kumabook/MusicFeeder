//
//  TopicRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/29/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift
import FeedlyKit

open class TopicRepository {
    public enum State {
        case cacheOnly
        case cacheOnlyFetching
        case normal
        case fetching
        case updating
        case error
    }
    public enum Event {
        case startLoading
        case completeLoading
        case failToLoad(Error)
        case startUpdating
        case failToUpdate(Error)
    }
    fileprivate let KEY: String = "topics"
    open static var shared: TopicRepository = TopicRepository(cloudApiClient: CloudAPIClient.shared)
    open fileprivate(set) var items:      [Topic] = []
    open fileprivate(set) var cacheItems: [Topic] = []
    open var cloudApiClient: CloudAPIClient
    
    open var state:                State
    open var signal:               Signal<Event, NSError>
    fileprivate var observer:            Signal<Event, NSError>.Observer

    public init(cloudApiClient: CloudAPIClient) {
        let pipe = Signal<Event, NSError>.pipe()
        self.cloudApiClient = cloudApiClient
        signal              = pipe.0
        observer            = pipe.1
        state               = .cacheOnly
        loadCacheItems()
    }
    open func getItems() -> [Topic] {
        switch state {
        case .cacheOnly:
            return cacheItems
        case .cacheOnlyFetching:
            return cacheItems
        default:
            return items
        }
    }
    open func fetch() {
        if state != .cacheOnly && state != .normal && state != .error {
            return
        }
        if state == .cacheOnly {
            state = .cacheOnlyFetching
        } else {
            state = .fetching
        }
        observer.send(value: .startLoading)
        cloudApiClient.fetchTopics().on(
            failed: { error in
                print("Failed to fetch topics \(error)")
        }, completed: {
            self.state = .normal
            self.observer.send(value: .completeLoading)
        }, value: { topics in
            self.items = topics
        }
        ).start()
    }
    open func loadCacheItems() {
        cloudApiClient.fetchTopics(useCache: true).on(failed: { error in
            print("No cache")
        }, value: { topics in
            self.cacheItems = topics
        }).start()
    }
}
