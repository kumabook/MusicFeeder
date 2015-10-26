//
//  TrackHistoryStore.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/25/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm

public class TrackHistoryStore: RLMObject {
    static let maxLength:  UInt = 10
    static let limit:      UInt = 5
    public dynamic var id:        String = ""
    public dynamic var timestamp: Int64  = 0
    public dynamic var track:     TrackStore!

    override init() {
        super.init()
    }

    convenience init(id: String, timestamp: Int64, trackStore: TrackStore) {
        self.init()
        self.id        = id
        self.timestamp = timestamp
        self.track     = trackStore
    }

    convenience init(trackStore: TrackStore) {
        self.init(id: NSUUID().UUIDString, timestamp: NSDate().timestamp, trackStore: trackStore)
    }

    class var realm: RLMRealm {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("history")
        path = path.stringByAppendingPathExtension("realm")!
        return RLMRealm(path: path as String)
    }

    public class func add(track: Track) -> Bool {
        removeOldestIfExceed()
        var history: TrackHistoryStore
        let results = TrackStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "url = %@", track.url))
        if results.count == 0 {
            history = TrackHistoryStore(trackStore: track.toStoreObject())
        } else {
            history = TrackHistoryStore(trackStore: (results[0] as? TrackStore)!)
        }
        realm.transactionWithBlock() {
            self.realm.addObject(history)
        }
        return true
    }

    private class func removeOldestIfExceed() {
        var results = TrackHistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: true)
        if results.count >= maxLength {
            remove((results[0] as? TrackHistoryStore)!)
        }
    }

    public class func findBy(id id: String) -> TrackHistoryStore? {
        let results = TrackHistoryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? TrackHistoryStore
        }
    }

    public class func count() -> UInt {
        return TrackHistoryStore.allObjectsInRealm(realm).count
    }

    public class func find(range: Range<UInt>) -> [TrackHistoryStore] {
        var results = TrackHistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: false)

        var r: Range<UInt>
        if range.endIndex > results.count {
            r = Range<UInt>(start: range.startIndex, end: results.count)
        } else {
            r = range
        }

        var historyStores: [TrackHistoryStore] = []
        for i in r {
            historyStores.append(results[i] as! TrackHistoryStore)
        }
        return historyStores
    }

    public class func remove(history: TrackHistoryStore) {
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