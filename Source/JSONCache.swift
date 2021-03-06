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
    let diskConfig = DiskConfig(name: "JSONCache")
    let memoryConfig = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
    lazy var storage = try? Storage<String>.init(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forCodable(ofType: String.self))

    public static var shared: JSONCache = JSONCache()

    public init(cacheLifetimeSec: TimeInterval = 60 * 60 * 24 * 3) {
        self.cacheLifetimeSec = cacheLifetimeSec
    }

    public func add(_ jsonString: String, forKey: String) throws {
        try storage?.setObject(jsonString, forKey: forKey, expiry: Expiry.seconds(cacheLifetimeSec))
    }

    public func get(forKey: String) -> String? {
        return (try? storage?.object(forKey: forKey))?.flatMap { $0 }
    }

    public func clear() {
        try? storage?.removeAll()
    }

    public func clearExpired() {
        try? storage?.removeExpiredObjects()

    }
}
