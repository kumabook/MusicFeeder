//
//  TopicRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/29/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class TopicRepository {
    public enum State {
        case CacheOnly
        case CacheOnlyFetching
        case Normal
        case Fetching
        case Updating
        case Error
    }
    public enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad(ErrorType)
        case StartUpdating
        case FailToUpdate(ErrorType)
    }
    private let KEY: String = "topics"
    public static var sharedInstance: TopicRepository = TopicRepository(cloudApiClient: CloudAPIClient.sharedInstance)
    public private(set) var items:      [Topic] = []
    public private(set) var cacheItems: [Topic] = []
    private var cacheList: TopicCacheList
    public var cloudApiClient: CloudAPIClient
    
    public var state:                State
    public var signal:               Signal<Event, NSError>
    private var observer:            Signal<Event, NSError>.Observer

    public init(cloudApiClient: CloudAPIClient) {
        let pipe = Signal<Event, NSError>.pipe()
        self.cloudApiClient = cloudApiClient
        signal              = pipe.0
        observer            = pipe.1
        cacheList           = TopicCacheList.findOrCreate(KEY)
        state               = .CacheOnly
        loadCacheItems()
    }
    public func getItems() -> [Topic] {
        switch state {
        case .CacheOnly:
            return cacheItems
        case .CacheOnlyFetching:
            return cacheItems
        default:
            return items
        }
    }
    public func fetch() {
        if state != .CacheOnly && state != .Normal && state != .Error {
            return
        }
        if state == .CacheOnly {
            state = .CacheOnlyFetching
        } else {
            state = .Fetching
        }
        observer.sendNext(.StartLoading)
        cloudApiClient.fetchTopics().on(
            next: { topics in
                self.cacheList.clear()
                self.cacheList = TopicCacheList.findOrCreate(self.KEY)
                self.cacheList.add(topics)
                self.items = topics
            }, completed: {
                self.state = .Normal
                self.observer.sendNext(.CompleteLoading)
            }, failed: { error in
                print("Failed to fetch topics \(error)")
            }
        ).start()
    }
    public func loadCacheItems() {
        cacheItems = cacheList.items.map { Topic(store: $0 as! TopicStore) }
    }
}