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
    public static var groupIdentifier: String = "group.com.your.app"
    public static var schemaVersion:    UInt64 = 13
    public static var subSchemaVersion: UInt64 = 7
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
        print("Current local schema version is \(val), latest schema version is \(schemaVersion)")
        if val == 0 {
            print("No schem version, delete local realm db first")
            do {
                try fileManager.removeItem(atPath: cacheSetPath)
                print("Succeeded delete realm file: \(cacheSetPath)")
                try fileManager.removeItem(atPath: cacheListPath)
                print("Succeeded delete realm file: \(cacheSetPath)")
            } catch {
                print("Failed to delete realm file")
            }
        }
        UserDefaults.standard.setValue(schemaVersion, forKey: key)
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
                        new["entries"]    = RLMArray<EntryStore>(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray<ProfileStore>(objectClassName: ProfileStore.className())
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
         ]
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
    public static var listenItLaterPath: String {
        #if os(iOS)
            if let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
                let path: NSString = directory.path as NSString
                return path.appendingPathComponent("db.realm")
            }
        #endif
        return RLMRealmConfiguration.default().fileURL!.path
    }
    open class func migrateListenItLater() {
        try? RLMRealm.performMigration(for: RealmMigration.configurationOf(RealmMigration.listenItLaterPath))
    }
    public static func realmPath(_ name: String) -> String {
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
                        new["entries"]    = RLMArray<EntryStore>(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray<ProfileStore>(objectClassName: ProfileStore.className())
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
        let fm = FileManager()
        if fm.fileExists(atPath: RealmMigration.cacheListPath) {
            try? fm.removeItem(atPath: RealmMigration.cacheListPath)
            try? fm.removeItem(atPath: RealmMigration.cacheSetPath)
        }
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
