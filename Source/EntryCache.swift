//
//  EntryCache.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/10/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Realm
import FeedlyKit
import Result

public final class EntryCacheList: RLMObject, CacheList {
    public typealias Item   = Entry
    public typealias Object = EntryStore
    public static var objectClassName: String { return EntryStore.className() }
    
    public override class func primaryKey() -> String {
        return "id"
    }
    
    dynamic public var id:        String   = ""
    dynamic public var timestamp: Int64    = 0
    dynamic public var items:     RLMArray = RLMArray(objectClassName: EntryStore.className())

    public static func deleteAllItems() {
        materialize(try realm.transactionWithBlock()
            {
                realm.deleteObjects(EntryStore.allObjectsInRealm(realm))
                realm.deleteObjects(allObjectsInRealm(realm))
            }
        )
    }
}

extension Entry: Cacheable {
    public func toCacheStoreObject(realm: RLMRealm) -> EntryStore {
        return toStoreObject()
    }
}
