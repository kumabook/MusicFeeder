//
//  EntryHistory.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/17/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import FeedlyKit

public struct EntryHistory {
    public var id:        String
    public var timestamp: Int64
    public var entry:     Entry

    public init(store: EntryHistoryStore) {
        id        = store.id
        timestamp = store.timestamp
        entry     = Entry(store: store.entry)
    }

    public func toStoreObject() -> EntryHistoryStore {
        return EntryHistoryStore(id: id, timestamp: timestamp, entryStore: entry.toStoreObject())
    }
}