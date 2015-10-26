//
//  TrackHistory.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/25/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation

public struct TrackHistory {
    public var id:        String
    public var timestamp: Int64
    public var track:     Track

    public init(store: TrackHistoryStore) {
        id        = store.id
        timestamp = store.timestamp
        track     = Track(store: store.track)
    }

    public func toStoreObject() -> TrackHistoryStore {
        return TrackHistoryStore(id: id, timestamp: timestamp, trackStore: track.toStoreObject())
    }
}