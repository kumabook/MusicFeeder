//
//  EntryHistoryStore.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

public class EntryHistoryStore: RLMObject {
    static let maxLength:  UInt = 10
    static let limit:      UInt = 5
    public dynamic var id:        String = ""
    public dynamic var timestamp: Int64  = 0
    public dynamic var entry:     EntryStore!

    override init() {
        super.init()
    }

    convenience init(id: String, timestamp: Int64, entryStore: EntryStore) {
        self.init()
        self.id        = id
        self.timestamp = timestamp
        self.entry     = entryStore
    }

    convenience init(entryStore: EntryStore) {
        self.init(id: NSUUID().UUIDString, timestamp: NSDate().timestamp, entryStore: entryStore)
    }

    class var realm: RLMRealm {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("history")
        path = path.stringByAppendingPathExtension("realm")!
        return RLMRealm(path: path as String)
    }

    public class func add(entry: Entry) -> Bool {
        removeOldestIfExceed()
        var history: EntryHistoryStore
        let results = EntryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", entry.id))
        if results.count == 0 {
            history = EntryHistoryStore(entryStore: entry.toStoreObject())
        } else {
            history = EntryHistoryStore(entryStore: (results[0] as? EntryStore)!)
        }
        realm.transactionWithBlock() {
            self.realm.addObject(history)
        }
        return true
    }

    private class func removeOldestIfExceed() {
        var results = EntryHistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: true)
        if results.count >= maxLength {
            remove((results[0] as? EntryHistoryStore)!)
        }
    }

    public class func findBy(id id: String) -> EntryHistoryStore? {
        let results = EntryHistoryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? EntryHistoryStore
        }
    }

    public class func count() -> UInt {
        return EntryHistoryStore.allObjectsInRealm(realm).count
    }

    public class func find(range: Range<UInt>) -> [EntryHistoryStore] {
        var results = EntryHistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: false)

        var r: Range<UInt>
        if range.endIndex > results.count {
            r = Range<UInt>(start: range.startIndex, end: results.count)
        } else {
            r = range
        }

        var historyStores: [EntryHistoryStore] = []
        for i in r {
            historyStores.append(results[i] as! EntryHistoryStore)
        }
        return historyStores
    }

    public class func remove(history: EntryHistoryStore) {
        if let store = findBy(id: history.id) {
            realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    public class func removeAll() {
        realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }
}