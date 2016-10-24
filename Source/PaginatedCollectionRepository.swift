//
//  PaginatedCollectionRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result

public enum PaginatedCollectionRepositoryState {
    case CacheOnly
    case CacheOnlyFetching
    case Normal
    case Fetching
    case Complete
    case Error
}

public enum PaginatedCollectionRepositoryEvent {
    case StartLoadingLatest
    case CompleteLoadingLatest
    case StartLoadingNext
    case CompleteLoadingNext
    case FailToLoadNext
    case CompleteLoadingPlaylist(Playlist, Entry)
    case CompleteLoadingTrackDetail(Track)
    case RemoveAt(Int)
}

public protocol PaginatedCollection {
    associatedtype ItemType
    var id:           String     { get }
    var updated:      Int64?     { get }
    var continuation: String?    { get }
    var title:        String?    { get }
    var direction:    String?    { get }
    var alternate:    Link?      { get }
    var items:        [ItemType] { get }
}

public class PaginatedCollectionRepository<C: PaginatedCollection, I where C.ItemType == I> {
    public internal(set) var stream:       Stream
    public internal(set) var state:        PaginatedCollectionRepositoryState
    public internal(set) var items:        [I] { didSet(newItems) { itemsUpdated() }}
    public internal(set) var cacheItems:   [I] { didSet(newItems) { itemsUpdated() }}
    public internal(set) var continuation: String?
    public internal(set) var lastUpdated:  Int64?
    public internal(set) var signal:       Signal<PaginatedCollectionRepositoryEvent, NSError>
    public internal(set) var observer:     Signal<PaginatedCollectionRepositoryEvent, NSError>.Observer
    public internal(set) var unreadOnly:   Bool
    public internal(set) var perPage:      Int
    public internal(set) var disposable:   Disposable?

    public var paginationParams: MusicFeeder.PaginationParams {
        let params          = MusicFeeder.PaginationParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        return params
    }

    public var paginationParamsForLatest: MusicFeeder.PaginationParams {
        let params        = MusicFeeder.PaginationParams()
        params.newerThan  = lastUpdated
        params.unreadOnly = unreadOnly
        params.count      = perPage
        return params
    }

    public init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        self.stream      = stream
        self.unreadOnly  = unreadOnly
        self.perPage     = perPage
        state            = .Normal
        lastUpdated      = nil
        items            = []
        cacheItems       = []
        let pipe         = Signal<PaginatedCollectionRepositoryEvent, NSError>.pipe()
        signal           = pipe.0
        observer         = pipe.1
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { self.unreadOnly = false }
            if stream == Tag.Read(userId)  { self.unreadOnly = false }
        }
        QueueScheduler().schedule {
            self.loadCacheItems()
            self.state = .CacheOnly
        }
    }

    public func dispose() {
        disposable?.dispose()
        disposable = nil
    }

    public func itemsUpdated() {}
    
    public func getItems() -> [I] {
        switch state {
        case .CacheOnly:
            return cacheItems
        case .CacheOnlyFetching:
            return cacheItems
        default:
            return items
        }
    }

    public func fetchCollection(streamId streamId: String, paginationParams: MusicFeeder.PaginationParams) -> SignalProducer<C, NSError> {
        return SignalProducer<C, NSError>.empty
    }

    func updateLastUpdated() {
        lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
    }
    
    public func fetchLatestItems() {
        if state != .CacheOnly && state != .Normal && state != .Error {
            return
        }
        if state == .CacheOnly {
            state = .CacheOnlyFetching
        } else {
            state = .Fetching
        }
        let producer = fetchCollection(streamId: stream.streamId,
                               paginationParams: paginationParamsForLatest)
        observer.sendNext(.StartLoadingLatest)
        disposable = producer
            .startOn(QueueScheduler())
            .on(
                next: { paginatedCollection in
                    let latestItems = paginatedCollection.items
                    self.items = latestItems
                    self.updateLastUpdated()
                    if latestItems.count > 0 {
                        self.clearCacheItems()
                    }
                    self.addCacheItems(self.items)
                    self.loadCacheItems()
                    UIScheduler().schedule {
                        self.observer.sendNext(.CompleteLoadingLatest) // First reload tableView,
                        if paginatedCollection.continuation == nil {   // then wait for next load
                            self.state = .Complete
                        } else {
                            self.state = .Normal
                        }
                    }
                },
                failed: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                }
            ).start()
    }
    public func fetchItems() {
        if state != .CacheOnly && state != .Normal && state != .Error {
            return
        }
        if state == .CacheOnly {
            state = .CacheOnlyFetching
        } else {
            state = .Fetching
        }
        observer.sendNext(.StartLoadingNext)
        let producer = fetchCollection(streamId: stream.streamId, paginationParams: paginationParams)
        disposable = producer
            .startOn(QueueScheduler())
            .on(
                next: { paginatedCollection in
                    let items = paginatedCollection.items
                    self.items.appendContentsOf(items)
                    self.continuation = paginatedCollection.continuation
                    if self.lastUpdated == nil {
                        self.updateLastUpdated()
                    }
                    if self.items.count > 0 {
                        self.clearCacheItems() // need to be optimized: append new items only
                        self.addCacheItems(self.items)
                    }
                    self.loadCacheItems()
                    UIScheduler().schedule {
                        self.observer.sendNext(.CompleteLoadingNext) // First reload tableView,
                        if paginatedCollection.continuation == nil { // then wait for next load
                            self.state = .Complete
                        } else {
                            self.state = .Normal
                        }
                    }
                },
                failed: {error in
                    CloudAPIClient.handleError(error: error)
                    self.observer.sendNext(.FailToLoadNext)
                    self.state = .Error
                },
                completed: {
            }).start()
    }
    public func addCacheItems(items: [C.ItemType]) {}
    public func loadCacheItems() {}
    public func clearCacheItems() {}
}
