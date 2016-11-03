//
//  History.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/31/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit
import Breit


public enum HistoryType: String {
    case Entry = "Entry"
    case Track = "Track"
    public var actionName: String {
        switch self {
        case .Entry: return "Read"
        case .Track: return "Played"
        }
    }
}

open class History: Equatable, Hashable {
    open var id:         String
    open var type:       HistoryType
    open var timestamp:  Int64
    
    open var entry: Entry?
    open var track: Track?
    
    open var hashValue: Int {
        return id.hashValue
    }
    
    public init(store: HistoryStore) {
        id        = store.id
        timestamp = store.timestamp
        type      = HistoryType(rawValue: store.type)!
        switch type {
        case .Entry:
            entry = Entry(store: store.entry!)
        case .Track:
            track = Track(store: store.track!)
        }
    }
    
    open func toStoreObject() -> HistoryStore {
        return HistoryStore(id: id, timestamp: timestamp, type: type.rawValue)
    }
}

public func ==(lhs: History, rhs: History) -> Bool {
    return lhs.id == rhs.id
}

