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
    case failToLoadNext(NSError)
    case completeLoadingPlaylist(Playlist, Entry)
    case completeLoadingTrackDetail(Track)
    case removeAt(Int)
    case updatedAt(Int)
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

    open var paginationParams: FeedlyKit.PaginationParams {
        let params          = MusicFeeder.PaginationParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        return params
    }

    open var paginationParamsForLatest: FeedlyKit.PaginationParams {
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
            if stream == Tag.saved(userId) { self.unreadOnly = false }
            if stream == Tag.read(userId)  { self.unreadOnly = false }
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

    open func fetchCollection(streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<C, NSError> {
        return SignalProducer<C, NSError>.empty
    }

    func updateLastUpdated() {
        lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
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
                failed: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                },
                value: { paginatedCollection in
                    let latestItems = paginatedCollection.items
                    self.items.insert(contentsOf: latestItems, at: 0)
                    self.updateLastUpdated()
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
        disposable = fetchCollection(streamId: stream.streamId, paginationParams: paginationParams)
            .start(on: QueueScheduler())
            .on(
                failed: {error in
                    CloudAPIClient.handleError(error: error)
                    DispatchQueue.main.async() {
                        self.observer.send(value: .failToLoadNext(error))
                    }
                    self.state = .error
                },
                completed: {
                },
                value: { paginatedCollection in
                    let items = paginatedCollection.items
                    self.items.append(contentsOf: items)
                    self.continuation = paginatedCollection.continuation
                    if self.lastUpdated == nil {
                        self.updateLastUpdated()
                    }
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
            }).start()
    }
    public func fetchCacheItems() {
        state = .fetchingCache
        fetchCollection(streamId: stream.streamId, paginationParams: paginationParams, useCache: true).on(failed: {_ in
            self.state = .cacheOnly
            UIScheduler().schedule {
                DispatchQueue.main.async() {
                    self.observer.send(value: .completeLoadingCache)
                }
            }
        }, value: { paginatedCollection in
            self.cacheItems = paginatedCollection.items
            self.state = .cacheOnly
            UIScheduler().schedule {
                DispatchQueue.main.async() {
                    self.observer.send(value: .completeLoadingCache)
                }
            }
        }).start()
    }
}
