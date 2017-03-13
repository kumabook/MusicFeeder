//
//  SavedStreamRepository.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/4/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift
import FeedlyKit

open class SavedStream: FeedlyKit.Stream {
    let id:    String
    let title: String

    init(id: String, title: String) {
        self.id    = id
        self.title = title
    }
    override open var streamId: String {
        return id
    }
    override open var streamTitle: String {
        return title
    }
    override open var thumbnailURL: URL? {
        return nil
    }
    override open var hashValue: Int {
        return streamId.hashValue
    }
}

open class SavedEntryRepository: EntryRepository {
    public override init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    public convenience init() {
        self.init(stream: SavedStream(id: "saved_stream", title: "Saved"), unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title), unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    open override func fetchCacheItems() {
        fetchItems()
    }

    open override func fetchCollection(streamId: String, paginationParams paginatedParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return SignalProducer { (observer, disposable) in
            QueueScheduler().schedule {
                // TODO: support pagination
                let entries: [Entry] = EntryStore.findAll().map { Entry(store: $0) }.reversed()
                self.playlistifier = entries.map { self.playlistify($0) }
                                            .reduce(SignalProducer<(Track, Playlist), NSError>.empty, { $0.concat($1) })
                                            .start()
                self.items = entries
                UIScheduler().schedule {
                    self.observer.send(value: .completeLoadingLatest)
                }
            }
        }
    }
}
