//
//  SavedStreamRepository.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/4/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class SavedStream: Stream {
    let id:    String
    let title: String

    init(id: String, title: String) {
        self.id    = id
        self.title = title
    }
    override public var streamId: String {
        return id
    }
    override public var streamTitle: String {
        return title
    }
    override public var thumbnailURL: NSURL? {
        return nil
    }
    override public var hashValue: Int {
        return streamId.hashValue
    }
}

public class SavedStreamRepository: EntryRepository {
    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    public convenience init() {
        self.init(stream: SavedStream(id: "saved_stream", title: "Saved"), unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title), unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    public override func fetchCollection(streamId streamId: String, paginationParams paginatedParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return SignalProducer { (observer, disposable) in
            QueueScheduler().schedule {
                // TODO: support pagination
                let entries: [Entry] = EntryStore.findAll().map { Entry(store: $0) }.reverse()
                self.playlistifier = entries.map { self.loadPlaylistOfEntry($0) }
                                            .reduce(SignalProducer<(Track, Playlist), NSError>.empty, combine: { $0.concat($1) })
                                            .start()
                self.items = entries
                UIScheduler().schedule {
                    self.observer.sendNext(.CompleteLoadingLatest)
                }
            }
        }
    }
}