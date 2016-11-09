//
//  PaginatedCollectionRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveSwift
import Result

public enum PaginatedCollectionRepositoryState {
    case `init`
    case fetchingCache
    case cacheOnly
    case cacheOnlyFetching
    case normal
    case fetching
    case complete
    case error
}

public enum PaginatedCollectionRepositoryEvent {
    case startLoadingCache
    case completeLoadingCache
    case startLoadingLatest
    case completeLoadingLatest
    case startLoadingNext
    case completeLoadingNext
    case failToLoadNext
    case completeLoadingPlaylist(Playlist, Entry)
    case completeLoadingTrackDetail(Track)
    case removeAt(Int)
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

open class PaginatedCollectionRepository<C: PaginatedCollection, I> where C.ItemType == I {
    open internal(set) var stream:       FeedlyKit.Stream
    open internal(set) var state:        PaginatedCollectionRepositoryState
    open internal(set) var items:        [I] { didSet(newItems) { itemsUpdated() }}
    open internal(set) var cacheItems:   [I] { didSet(newItems) { cacheItemsUpdated() }}
    open internal(set) var continuation: String?
    open internal(set) var lastUpdated:  Int64?
    open internal(set) var signal:       Signal<PaginatedCollectionRepositoryEvent, NSError>
    open internal(set) var observer:     Signal<PaginatedCollectionRepositoryEvent, NSError>.Observer
    open internal(set) var unreadOnly:   Bool
    open internal(set) var perPage:      Int
    open internal(set) var disposable:   Disposable?

    open var paginationParams: MusicFeeder.PaginationParams {
        let params          = MusicFeeder.PaginationParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        return params
    }

    open var paginationParamsForLatest: MusicFeeder.PaginationParams {
        let params        = MusicFeeder.PaginationParams()
        params.newerThan  = lastUpdated
        params.unreadOnly = unreadOnly
        params.count      = perPage
        return params
    }

    public init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
        self.stream      = stream
        self.unreadOnly  = unreadOnly
        self.perPage     = perPage
        state            = .init
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
    }

    open func dispose() {
        disposable?.dispose()
        disposable = nil
    }

    open func itemsUpdated() {}
    open func cacheItemsUpdated() {}
    
    open func getItems() -> [I] {
        switch state {
        case .fetchingCache:
            return cacheItems
        case .cacheOnly:
            return cacheItems
        case .cacheOnlyFetching:
            return cacheItems
        default:
            return items
        }
    }

    open func fetchCollection(streamId: String, paginationParams: MusicFeeder.PaginationParams) -> SignalProducer<C, NSError> {
        return SignalProducer<C, NSError>.empty
    }

    func updateLastUpdated() {
        lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
    }

    open func fetchCacheItems() {
        state = .fetchingCache
        DispatchQueue.main.async() {
            self.observer.send(value: .startLoadingCache)
            self.loadCacheItems()
            self.state = .cacheOnly
            DispatchQueue.main.async() {
                self.observer.send(value: .completeLoadingCache)
            }
        }
    }
    
    open func fetchLatestItems() {
        if state != .init && state != .cacheOnly && state != .normal && state != .error {
            return
        }
        if state == .cacheOnly {
            state = .cacheOnlyFetching
        } else {
            state = .fetching
        }
        let producer = fetchCollection(streamId: stream.streamId,
                               paginationParams: paginationParamsForLatest)
        UIScheduler().schedule {
            self.observer.send(value: .startLoadingLatest)
        }
        disposable = producer
            .start(on: QueueScheduler())
            .on(
                value: { paginatedCollection in
                    let latestItems = paginatedCollection.items
                    self.items = latestItems
                    self.updateLastUpdated()
                    if latestItems.count > 0 {
                        self.clearCacheItems()
                    }
                    self.addCacheItems(self.items)
                    self.loadCacheItems()
                    UIScheduler().schedule {
                        DispatchQueue.main.async() {
                            self.observer.send(value: .completeLoadingLatest) // First reload tableView,
                        }
                        if paginatedCollection.continuation == nil {   // then wait for next load
                            self.state = .complete
                        } else {
                            self.state = .normal
                        }
                    }
                },
                failed: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                }
            ).start()
    }
    open func fetchItems() {
        if state != .init && state != .cacheOnly && state != .normal && state != .error {
            return
        }
        if state == .cacheOnly {
            state = .cacheOnlyFetching
        } else {
            state = .fetching
        }
        DispatchQueue.main.async() {
            self.observer.send(value: .startLoadingNext)
        }
        let producer = fetchCollection(streamId: stream.streamId, paginationParams: paginationParams)
        disposable = producer
            .start(on: QueueScheduler())
            .on(
                value: { paginatedCollection in
                    let items = paginatedCollection.items
                    self.items.append(contentsOf: items)
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
                        DispatchQueue.main.async() {
                            self.observer.send(value: .completeLoadingNext)
                        }
                        if paginatedCollection.continuation == nil {
                            self.state = .complete
                        } else {
                            self.state = .normal
                        }
                    }
                },
                failed: {error in
                    CloudAPIClient.handleError(error: error)
                    DispatchQueue.main.async() {
                        self.observer.send(value: .failToLoadNext)
                    }
                    self.state = .error
                },
                completed: {
            }).start()
    }
    open var cacheKey: String { return stream.streamId }
    open func addCacheItems(_ items: [C.ItemType]) {}
    open func loadCacheItems() {}
    open func clearCacheItems() {}
}
