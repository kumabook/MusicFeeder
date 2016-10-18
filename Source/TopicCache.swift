//
//  TopicCache.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/15/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Realm
import FeedlyKit
import Result

public final class TopicCacheList: RLMObject, CacheList {
    public typealias Item   = Topic
    public typealias Object = TopicStore
    public static var objectClassName: String { return TopicStore.className() }
    
    public override class func primaryKey() -> String {
        return "id"
    }
    
    dynamic public var id:        String   = ""
    dynamic public var timestamp: Int64    = 0
    dynamic public var items:     RLMArray = RLMArray(objectClassName: TopicCacheList.objectClassName)
    
    public static func deleteAllItems() {
        materialize(try realm.transactionWithBlock()
            {
                realm.deleteObjects(TopicStore.allObjectsInRealm(realm))
                realm.deleteObjects(allObjectsInRealm(realm))
            }
        )
    }
}

extension Topic: Cacheable {
    public func toCacheStoreObject(realm: RLMRealm) -> TopicStore {
        return toStoreObject()
    }
}
