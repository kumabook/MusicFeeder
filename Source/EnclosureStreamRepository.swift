//
//  EnclosureStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/22.
//  Copyright © 2017 kumabook. All rights reserved.
//

import FeedlyKit
import ReactiveSwift
import Result

open class EnclosureStreamRepository<T: Enclosure>: PaginatedCollectionRepository<PaginatedEnclosureCollection<T>, T> {
    public typealias State = PaginatedCollectionRepositoryState
    public typealias Event = PaginatedCollectionRepositoryEvent
    
    open fileprivate(set) var feedlyClient = CloudAPIClient.sharedInstance
    open var sharedObserver: Disposable?

    open override func fetchCollection(streamId: String, paginationParams: MusicFeeder.PaginationParams)-> SignalProducer<PaginatedEnclosureCollection<T>, NSError> {
        return feedlyClient.fetchEnclosuresOf(streamId, paginationParams: paginationParams)
    }

    deinit {
        dispose()
    }
    
    open var detailLoader: Disposable?
    
    public override init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
        observe()
    }

    public func observe() {
        fatalError("should be overrided")
    }

    open override func dispose() {
        sharedObserver?.dispose()
        sharedObserver = nil
    }

    // MARK: - PaginatedCollectionRepository protocol
    
    open override func addCacheItems(_ items: [T]) {
        // not support
    }
    open override func loadCacheItems() {
        // not support
    }
    open override func clearCacheItems() {
        // not support
    }
    open override func cacheItemsUpdated() {
        // not support
    }
    open override func itemsUpdated() {
    }
    open func markAs(_ action: MarkerAction, at index: Int) {
        let item = items[index]
        item.markAs(action: action).startWithResult { result in
            if let error = result.error {
                print("Failed to mark as \(action) \(error)")
            } else if let newItem = result.value {
                print("Succeeded in marking as \(action)")
                self.items[index] = newItem
                item.updateMarkProperties(item: newItem)
                self.observer.send(value: .updatedAt(index))
                newItem.sendToSharedPipe()
            }
        }
    }
}
