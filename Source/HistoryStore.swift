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

open class HistoryStore: RLMObject {
    static let maxLength:  UInt = 10
    static let limit:      UInt = 10

    class var realm: RLMRealm {
        return try! RLMRealm(configuration: RealmMigration.configurationOf(RealmMigration.historyPath))
    }

    override open class func primaryKey() -> String {
        return "id"
    }

    open override class func requiredProperties() -> [String] {
        return ["id", "type"]
    }

    @objc open dynamic var id:        String = ""
    @objc open dynamic var type:      String = ""
    @objc open dynamic var timestamp: Int64  = 0

    open var entry: EntryStore? {
        if type == HistoryType.Entry.rawValue {
            let results = EntryStore.objects(in: HistoryStore.realm, with: NSPredicate(format: "id = %@", id))
            if results.count > 0 {
                return results[0] as? EntryStore
            }
        }
        return nil
    }

    open var track: TrackStore? {
        if type == HistoryType.Track.rawValue {
            let results = TrackStore.objects(in: HistoryStore.realm, with: NSPredicate(format: "url = %@", id))
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

    open class func add(_ entry: Entry) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: entry.id) {
            try! realm.transaction() {
                history.timestamp = Date().timestamp
                self.realm.addOrUpdate(history)
            }
            return history
        }
        let history = HistoryStore(id: entry.id,
                            timestamp: Date().timestamp,
                                 type: HistoryType.Entry.rawValue)
        try! realm.transaction() {
            self.realm.addOrUpdate(findOrCreateEntryStore(entry))
            self.realm.addOrUpdate(history)
        }
        return history
    }

    open class func add(_ track: Track) -> HistoryStore {
        removeOldestIfExceed()
        if let history = HistoryStore.findBy(id: track.url) {
            try! realm.transaction() {
                history.timestamp = Date().timestamp
                self.realm.addOrUpdate(history)
            }
            return history
        }
        let history = HistoryStore(id: track.url,
                            timestamp: Date().timestamp,
                                 type: HistoryType.Track.rawValue)
        try! realm.transaction() {
            self.realm.addOrUpdate(findOrCreateTrackStore(track))
            self.realm.addOrUpdate(history)
        }
        return history
    }

    fileprivate class func removeOldestIfExceed() {
        var results = HistoryStore.allObjects(in: realm)
        results = results.sortedResults(usingKeyPath: "timestamp", ascending: true)
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

    open class func findBy(id: String) -> HistoryStore? {
        let results = HistoryStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? HistoryStore
        }
    }

    open class func count() -> UInt {
        return HistoryStore.allObjects(in: realm).count
    }

    open class func find(_ range: CountableRange<UInt>) -> [HistoryStore] {
        var results = HistoryStore.allObjects(in: realm)
        results = results.sortedResults(usingKeyPath: "timestamp", ascending: false)

        var r: CountableRange<UInt>
        if range.upperBound > results.count {
            r = range.lowerBound..<results.count
        } else {
            r = range
        }

        var historyStores: [HistoryStore] = []
        for i in r {
            historyStores.append(results[i] as! HistoryStore)
        }
        return historyStores
    }

    open class func remove(_ history: HistoryStore) {
        if let store = findBy(id: history.id) {
            try! realm.transaction() {
                self.realm.delete(store)
            }
        }
    }

    open class func removeAll() {
        try! realm.transaction() {
            self.realm.deleteAllObjects()
        }
    }

    fileprivate class func findOrCreateEntryStore(_ entry: Entry) -> EntryStore {
        let results = EntryStore.objects(in: HistoryStore.realm, with: NSPredicate(format: "id = %@", entry.id))
        if results.count > 0 {
            return results[0] as! EntryStore
        }
        return entry.toStoreObject()
    }

    fileprivate class func findOrCreateTrackStore(_ track: Track) -> TrackStore {
        let results = TrackStore.objects(in: HistoryStore.realm, with: NSPredicate(format: "url = %@", track.url))
        if results.count > 0 {
            return results[0] as! TrackStore
        }
        return track.toStoreObject()
    }
}
