//
//  TrackCache.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/10/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Realm
import FeedlyKit
import Result

public final class TrackCacheList: RLMObject, CacheList {
    public typealias Item   = Track
    public typealias Object = TrackStore
    public static var objectClassName: String { return TrackStore.className() }

    public override class func primaryKey() -> String {
        return "id"
    }
    dynamic public var id:        String   = ""
    dynamic public var timestamp: Int64    = 0
    dynamic public var items:     RLMArray = RLMArray(objectClassName: TrackStore.className())
}

public final class TrackCacheEntity: RLMObject, CacheEntity {
    dynamic public var id:        String   = ""
    dynamic public var timestamp: Int64    = 0
    dynamic public var item:      TrackStore?
    public override class func primaryKey() -> String {
        return "id"
    }
}

public final class TrackCacheMap: RLMObject, CacheMap {
    public typealias Item = Track
    public typealias Object = TrackStore
    public typealias Entity = TrackCacheEntity
    public static var objectClassName: String { return TrackStore.className() }
}

extension Track: Cacheable {
    public func toCacheStoreObject() -> TrackStore {
        let store = toStoreObject()
        entries?.forEach {e in
            store.entries.addObject(e.toStoreObject())
        }
        likers?.forEach {p in
            store.likers.addObject(p.toStoreObject())
        }
        return toStoreObject()
    }
}