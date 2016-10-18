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
    static let limit:      UInt = 10

    class var realm: RLMRealm {
        return try! RLMRealm(configuration: RealmMigration.configurationOf(RealmMigration.historyPath))
    }

    override public class func primaryKey() -> String {
        return "id"
    }

    public override class func requiredProperties() -> [String] {
        return ["id", "type"]
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

    public class func add(entry: Entry) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: entry.id) {
            try! realm.transactionWithBlock() {
                history.timestamp = NSDate().timestamp
                self.realm.addOrUpdateObject(history)
            }
            return history
        }
        let history = HistoryStore(id: entry.id,
                            timestamp: NSDate().timestamp,
                                 type: HistoryType.Entry.rawValue)
        try! realm.transactionWithBlock() {
            self.realm.addOrUpdateObject(findOrCreateEntryStore(entry))
            self.realm.addOrUpdateObject(history)
        }
        return history
    }

    public class func add(track: Track) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: track.url) {
            try! realm.transactionWithBlock() {
                history.timestamp = NSDate().timestamp
                self.realm.addOrUpdateObject(history)
            }
            return history
        }
        let history = HistoryStore(id: track.url,
                            timestamp: NSDate().timestamp,
                                 type: HistoryType.Track.rawValue)
        try! realm.transactionWithBlock() {
            self.realm.addOrUpdateObject(findOrCreateTrackStore(track))
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
            r = range.startIndex..<results.count
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
            try! realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    public class func removeAll() {
        try! realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }

    private class func findOrCreateEntryStore(entry: Entry) -> EntryStore {
        let results = EntryStore.objectsInRealm(HistoryStore.realm, withPredicate: NSPredicate(format: "id = %@", entry.id))
        if results.count > 0 {
            return results[0] as! EntryStore
        }
        return entry.toStoreObject()
    }

    private class func findOrCreateTrackStore(track: Track) -> TrackStore {
        let results = TrackStore.objectsInRealm(HistoryStore.realm, withPredicate: NSPredicate(format: "url = %@", track.url))
        if results.count > 0 {
            return results[0] as! TrackStore
        }
        return track.toStoreObject()
    }
}