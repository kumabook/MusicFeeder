//
//  PaginatedCollectionLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result

public enum PaginatedCollectionLoaderState {
    case Normal
    case Fetching
    case Complete
    case Error
}

public enum PaginatedCollectionLoaderEvent {
    case StartLoadingLatest
    case CompleteLoadingLatest
    case StartLoadingNext
    case CompleteLoadingNext
    case FailToLoadNext
    case CompleteLoadingPlaylist(Playlist, Entry)
    case RemoveAt(Int)
}

public protocol PaginatedCollection {
    typealias ItemType
    var id:           String     { get }
    var updated:      Int64?     { get }
    var continuation: String?    { get }
    var title:        String?    { get }
    var direction:    String?    { get }
    var alternate:    Link?      { get }
    var items:        [ItemType] { get }
}

public class PaginatedCollectionLoader<C: PaginatedCollection, I where C.ItemType == I> {
    public internal(set) var stream:       Stream
    public internal(set) var state:        PaginatedCollectionLoaderState
    public internal(set) var items:        [I] { didSet(newItems) { itemsUpdated() }}
    public internal(set) var continuation: String?
    public internal(set) var lastUpdated:  Int64
    public internal(set) var signal:       Signal<PaginatedCollectionLoaderEvent, NSError>
    public internal(set) var observer:     Signal<PaginatedCollectionLoaderEvent, NSError>.Observer
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
        lastUpdated      = 0
        items            = []
        let pipe         = Signal<PaginatedCollectionLoaderEvent, NSError>.pipe()
        signal           = pipe.0
        observer         = pipe.1
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { self.unreadOnly = false }
            if stream == Tag.Read(userId)  { self.unreadOnly = false }
        }
    }

    public func dispose() {
        disposable?.dispose()
        disposable = nil
    }

    public func itemsUpdated() {}

    public func fetchCollection(streamId streamId: String, paginationParams: MusicFeeder.PaginationParams) -> SignalProducer<C, NSError> {
        return SignalProducer<C, NSError>.empty
    }

    func updateLastUpdated(updated: Int64?) {
        if let timestamp = updated {
            lastUpdated = timestamp + 1
        } else {
            lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
        }
    }
    
    public func fetchLatestItems() {
        if items.count == 0 {
            return
        }
        let producer = fetchCollection(streamId: stream.streamId,
                               paginationParams: paginationParamsForLatest)
        observer.sendNext(.StartLoadingLatest)
        disposable = producer
            .startOn(UIScheduler())
            .on(
                next: { paginatedCollection in
                    var latestItems = paginatedCollection.items
                    latestItems.appendContentsOf(self.items)
                    self.items = latestItems
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                failed: { error in CloudAPIClient.handleError(error: error) },
                completed: { self.observer.sendNext(.CompleteLoadingLatest)
            }).start()
    }
    public func fetchItems() {
        if state != .Normal && state != .Error {
            return
        }
        state = .Fetching
        observer.sendNext(.StartLoadingNext)
        let producer = fetchCollection(streamId: stream.streamId, paginationParams: paginationParams)
        disposable = producer
            .startOn(UIScheduler())
            .on(next: { paginatedCollection in
                let items = paginatedCollection.items
                self.items.appendContentsOf(items)
                self.continuation = paginatedCollection.continuation
                self.updateLastUpdated(paginatedCollection.updated)
                self.observer.sendNext(.CompleteLoadingNext) // First reload tableView,
                if paginatedCollection.continuation == nil { // then wait for next load
                    self.state = .Complete
                } else {
                    self.state = .Normal
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
}
