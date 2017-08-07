//
//  JSONCache.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/19.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit
import Result
import Cache

public final class JSONCache {
    public var cacheLifetimeSec: TimeInterval
    let cache = SpecializedCache<String>(name: "JSONCache")

    public static var shared: JSONCache = JSONCache()

    public init(cacheLifetimeSec: TimeInterval = 60 * 60 * 24 * 3) {
        self.cacheLifetimeSec = cacheLifetimeSec
    }

    public func add(_ jsonString: String, forKey: String) throws {
        try cache.addObject(jsonString, forKey: forKey, expiry: Expiry.seconds(cacheLifetimeSec))
    }

    public func get(forKey: String) -> String? {
        return cache.object(forKey: forKey)
    }

    public func clear() {
        try? cache.clear()
    }

    public func clearExpired() {
        try? cache.clearExpired()
    }

    public func cachedDiskSize() -> UInt64 {
        return (try? cache.totalDiskSize()) ?? 0
    }
}
