//
//  Migration.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 12/10/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm

open class RealmMigration {
    open static var groupIdentifier: String = "group.com.your.app"
    open static var schemaVersion:    UInt64 = 13
    open static var subSchemaVersion: UInt64 = 7
    open class func migrateAll() {
        migrateMain()
//        migrateListenItLater()
        migrateHistory()
        migrateCache()
    }
    
    open class func deleteCacheRealmIfNeeded() {
        let key = "schema_version"
        let val = UserDefaults.standard.value(forKey: key) as? UInt64 ?? 0
        let fileManager = FileManager.default
        if val == 0 {
            let _ = try? fileManager.removeItem(atPath: cacheSetPath)
            let _ = try? fileManager.removeItem(atPath: cacheListPath)
            UserDefaults.standard.setValue(schemaVersion, forKey: key)
        }
    }

    open class func deleteAllCacheItems() {
        TopicCacheList.deleteAllItems()
        EntryCacheList.deleteAllItems()
        TrackCacheList.deleteAllItems()
        TrackCacheSet.deleteAllItems()
    }
    
    open class func deleteOldCacheItems(before: Int64) {
        TopicCacheList.deleteOldItems(before: before)
        EntryCacheList.deleteOldItems(before: before)
        TrackCacheList.deleteOldItems(before: before)
        TrackCacheSet.deleteOldItems(before: before)
    }

    open class func mainConfiguration() -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration.default()
        config.schemaVersion = schemaVersion
        config.migrationBlock = { migration, oldVersion in
            if (oldVersion < 1) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, let new =  newObject {
                        new["identifier"] = old["serviceId"]
                    }
                }
            }
            if (oldVersion < 2) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, let new =  newObject {
                        let properties = ["title", "streamUrl", "thumbnailUrl"]
                        for prop in properties {
                            new[prop] = old[prop]
                        }
                    }
                }
            }
            if (oldVersion < 7) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, let new =  newObject {
                        let properties = ["title", "streamUrl", "thumbnailUrl"]
                        for prop in properties {
                            new[prop] = old[prop]
                        }
                    }
                }
                migration.enumerateObjects(EntryStore.className())        { oldObject, newObject in }
                migration.enumerateObjects(VisualStore.className())       { oldObject, newObject in }
                migration.enumerateObjects(OriginStore.className())       { oldObject, newObject in }
                migration.enumerateObjects(KeywordStore.className())      { oldObject, newObject in }
                migration.enumerateObjects(TagStore.className())          { oldObject, newObject in }
                migration.enumerateObjects(LinkStore.className())         { oldObject, newObject in }
                migration.enumerateObjects(ContentStore.className())      { oldObject, newObject in }
                migration.enumerateObjects(HistoryStore.className())      { oldObject, newObject in }
                migration.enumerateObjects(SubscriptionStore.className()) { oldObject, newObject in }
                migration.enumerateObjects(TrackStore.className())        { oldObject, newObject in }
            }
            if (oldVersion < 8) {
                addIdToTrack(migration)
            }
            if (oldVersion < 9) {
                addTimestampsTo(PlaylistStore.className(), migration: migration)
            }
            if (oldVersion < 10) {
                addTimestampsTo(SubscriptionStore.className(), migration: migration)
            }
            if (oldVersion < 11) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let _ = oldObject, let new = newObject {
                        new["likesCount"] = 0
                        new["entries"]    = RLMArray(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray(objectClassName: ProfileStore.className())
                        new["expiresAt"]  = 0
                    }
                }
            }
            if (oldVersion < 12) {
                touchAllStore(migration: migration)
            }
            if (oldVersion < 13) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let _ = oldObject, let new = newObject {
                        new["entriesCount"] = 0
                    }
                }
            }
        }
        return config
    }

    private class func touchAllStore(migration: RLMMigration) {
        let objects: [(String, [String])] =
        [(ContentStore.className(),      ContentStore.requiredProperties()),
         (LinkStore.className(),         LinkStore.requiredProperties()),
         (KeywordStore.className(),      KeywordStore.requiredProperties()),
         (OriginStore.className(),       OriginStore.requiredProperties()),
         (VisualStore.className(),       VisualStore.requiredProperties()),
         (HistoryStore.className(),      HistoryStore.requiredProperties()),
         (TopicStore.className(),        TopicStore.requiredProperties()),
         (SubscriptionStore.className(), SubscriptionStore.requiredProperties()),
         (PlaylistStore.className(),     PlaylistStore.requiredProperties()),
         (TrackStore.className(),        TrackStore.requiredProperties()),
         (TagStore.className(),          TagStore.requiredProperties()),
         (EntryStore.className(),        EntryStore.requiredProperties()),
         (ProfileStore.className(),      ProfileStore.requiredProperties()),
         (EntryCacheList.className(),    EntryCacheList.requiredProperties()),
         (TopicCacheList.className(),    TopicCacheList.requiredProperties()),
         (TrackCacheList.className(),    TrackCacheList.requiredProperties()),
         (TrackCacheSet.className(),     TrackCacheSet.requiredProperties()),
         (TrackCacheEntity.className(),  TrackCacheEntity.requiredProperties())]
        objects.forEach {
            let className = $0.0
            let props     = $0.1
            migration.enumerateObjects(className, block: {oldObject, newObject in
                if let old = oldObject, let new = newObject {
                    for prop in props {
                        new[prop] = old[prop]
                    }
                }
            })
        }
    }

    open class func migrateMain() {
        RLMRealmConfiguration.setDefault(mainConfiguration())
        try? RLMRealm.performMigration(for: mainConfiguration())
    }
    open static var listenItLaterPath: String {
        #if os(iOS)
            if let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
                let path: NSString = directory.path as NSString
                return path.appendingPathComponent("db.realm")
            }
        #endif
        print("path : \(RLMRealmConfiguration.default().fileURL!.path)")
        return RLMRealmConfiguration.default().fileURL!.path
    }
    open class func migrateListenItLater() {
        try? RLMRealm.performMigration(for: RealmMigration.configurationOf(RealmMigration.listenItLaterPath))
    }
    open static func realmPath(_ name: String) -> String {
        var path: NSString = RLMRealmConfiguration.default().fileURL!.path as NSString
        path = path.deletingLastPathComponent as NSString
        path = path.appendingPathComponent(name) as NSString
        path = path.appendingPathExtension("realm")! as NSString
        return path as String
    }
    open class func configurationOf(_ path: String) -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration()
        config.fileURL = URL(fileURLWithPath: path)
        config.schemaVersion = subSchemaVersion
        config.migrationBlock = { migration, oldVersion in
            if (oldVersion < 1) {
                migration.enumerateObjects(ListenItLaterEntryStore.className()) { oldObject, newObject in }
            }
            if (oldVersion < 2) {
                addIdToTrack(migration)
            }
            if (oldVersion < 3) {
                addTimestampsTo(PlaylistStore.className(), migration: migration)
            }
            if (oldVersion < 4) {
                addTimestampsTo(SubscriptionStore.className(), migration: migration)
            }
            if (oldVersion < 5) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let _ = oldObject, let new = newObject {
                        new["likesCount"] = 0
                        new["entries"]    = RLMArray(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray(objectClassName: ProfileStore.className())
                        new["expiresAt"]  = 0
                        new["artist"]     = ""
                    }
                }
            }
            if (oldVersion < 6) {
                touchAllStore(migration: migration)
            }
            if (oldVersion < 7) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let _ = oldObject, let new = newObject {
                        new["entriesCount"] = 0
                    }
                }
            }
        }
        return config
    }
    open class var historyPath: String {
        var path: NSString = RLMRealmConfiguration.default().fileURL!.path as NSString
        path = path.deletingLastPathComponent as NSString
        path = path.appendingPathComponent("history") as NSString
        path = path.appendingPathExtension("realm")! as NSString
        return path as String
    }

    open class func migrateHistory() {
        try? RLMRealm.performMigration(for: RealmMigration.configurationOf(RealmMigration.historyPath))
        let _ = HistoryStore.realm
    }
    
    open class var cacheListPath: String {
        var path: NSString = RLMRealmConfiguration.default().fileURL!.path as NSString
        path = path.deletingLastPathComponent as NSString
        path = path.appendingPathComponent("cache_list") as NSString
        path = path.appendingPathExtension("realm")! as NSString
        return path as String
    }

    open class var cacheSetPath: String {
        var path: NSString = RLMRealmConfiguration.default().fileURL!.path as NSString
        path = path.deletingLastPathComponent as NSString
        path = path.appendingPathComponent("cache_map") as NSString
        path = path.appendingPathExtension("realm")! as NSString
        return path as String
    }

    open class func migrateCache() {
        try? RLMRealm.performMigration(for: RealmMigration.configurationOf(RealmMigration.cacheListPath))
        try? RLMRealm.performMigration(for: RealmMigration.configurationOf(RealmMigration.cacheSetPath))
        let _ = EntryCacheList.realm
        let _ = TrackCacheSet.realm
    }


    fileprivate class func addIdToTrack(_ migration: RLMMigration) {
        migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
            if let old = oldObject, let new =  newObject {
                let properties = ["title", "streamUrl", "thumbnailUrl"]
                for prop in properties {
                    new[prop] = old[prop]
                }
                new["id"] = "";
            }
        }
    }

    fileprivate class func addTimestampsTo(_ className: String, migration: RLMMigration) {
        var number: Float = 0
        migration.enumerateObjects(className) { oldObject, newObject in
            if let _ = oldObject, let new = newObject {
                new["createdAt"] = NSNumber(value: Date().timestamp)
                new["updatedAt"] = NSNumber(value: Date().timestamp)
                new["number"]    = NSNumber(value: number as Float)
                number -= 1
            }
        }
    }
}
