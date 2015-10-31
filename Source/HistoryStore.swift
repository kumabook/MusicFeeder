//
//  HistoryStore.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit
import Breit

public class HistoryStore: RLMObject {
    static let maxLength:  UInt = 10
    static let limit:      UInt = 5

    override public class func primaryKey() -> String {
        return "id"
    }

    public dynamic var id:        String = ""
    public dynamic var type:      String = ""
    public dynamic var timestamp: Int64  = 0

    public var entry: EntryStore? {
        if type == HistoryType.Entry.rawValue {
            let results = EntryStore.objectsInRealm(HistoryStore.realm, withPredicate: NSPredicate(format: "id = %@", id))
            if results.count > 0 {
                return results[0] as? EntryStore
            }
        }
        return nil
    }

    public var track: TrackStore? {
        if type == HistoryType.Track.rawValue {
            let results = TrackStore.objectsInRealm(HistoryStore.realm, withPredicate: NSPredicate(format: "url = %@", id))
            if results.count > 0 {
                return results[0] as? TrackStore
            }
        }
        return nil
    }

    override init() {
        super.init()
    }

    convenience init(id: String, timestamp: Int64, type: String) {
        self.init()
        self.id        = id
        self.timestamp = timestamp
        self.type      = type
    }

    class var realm: RLMRealm {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("history")
        path = path.stringByAppendingPathExtension("realm")!
        return RLMRealm(path: path as String)
    }

    public class func add(entry: Entry) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: entry.id) {
            realm.transactionWithBlock() {
                history.timestamp = NSDate().timestamp
                self.realm.addOrUpdateObject(history)
            }
            return history
        }
        let history = HistoryStore(id: entry.id,
                            timestamp: NSDate().timestamp,
                                 type: HistoryType.Entry.rawValue)
        realm.transactionWithBlock() {
            self.realm.addOrUpdateObject(entry.toStoreObject())
            self.realm.addOrUpdateObject(history)
        }
        return history
    }

    public class func add(track: Track) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: track.url) {
            realm.transactionWithBlock() {
                history.timestamp = NSDate().timestamp
                self.realm.addOrUpdateObject(history)
            }
            return history
        }
        let history = HistoryStore(id: track.url,
                            timestamp: NSDate().timestamp,
                                 type: HistoryType.Track.rawValue)
        realm.transactionWithBlock() {
            self.realm.addOrUpdateObject(track.toStoreObject())
            self.realm.addOrUpdateObject(history)
        }
        return history
    }

    private class func removeOldestIfExceed() {
        var results = HistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: true)
        if results.count >= maxLength {
            if let h = results[0] as? HistoryStore {
                switch HistoryType(rawValue: h.type)! {
                case .Entry:
                    EntryStore.remove(h.entry!)
                case .Track:
                    TrackStore.remove(h.track!)
                }
                remove(h)
            }
        }
    }

    public class func findBy(id id: String) -> HistoryStore? {
        let results = HistoryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? HistoryStore
        }
    }

    public class func count() -> UInt {
        return HistoryStore.allObjectsInRealm(realm).count
    }

    public class func find(range: Range<UInt>) -> [HistoryStore] {
        var results = HistoryStore.allObjectsInRealm(realm)
        results = results.sortedResultsUsingProperty("timestamp", ascending: false)

        var r: Range<UInt>
        if range.endIndex > results.count {
            r = Range<UInt>(start: range.startIndex, end: results.count)
        } else {
            r = range
        }

        var historyStores: [HistoryStore] = []
        for i in r {
            historyStores.append(results[i] as! HistoryStore)
        }
        return historyStores
    }

    public class func remove(history: HistoryStore) {
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