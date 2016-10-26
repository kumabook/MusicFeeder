//
//  Migration.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 12/10/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm

public class RealmMigration {
    public static var groupIdentifier: String = "group.com.your.app"
    public class func migrateAll() {
        migrateMain()
        migrateListenItLater()
        migrateHistory()
        migrateCache()
    }

    public class func mainConfiguration() -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration.defaultConfiguration()
        config.schemaVersion = 11
        config.migrationBlock = { migration, oldVersion in
            if (oldVersion < 1) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, new =  newObject {
                        new["identifier"] = old["serviceId"]
                    }
                }
            }
            if (oldVersion < 2) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, new =  newObject {
                        let properties = ["title", "streamUrl", "thumbnailUrl"]
                        for prop in properties {
                            new[prop] = old[prop]
                        }
                    }
                }
            }
            if (oldVersion < 7) {
                migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
                    if let old = oldObject, new =  newObject {
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
                    if let _ = oldObject, new = newObject {
                        new["likesCount"] = 0
                        new["entries"]    = RLMArray(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray(objectClassName: ProfileStore.className())
                        new["expiresAt"]  = 0
                    }
                }
            }
        }
        return config
    }

    public class func migrateMain() {
        RLMRealmConfiguration.setDefaultConfiguration(mainConfiguration())
        RLMRealm.defaultRealm()
    }
    public static var listenItLaterPath: String {
        let fileManager = NSFileManager.defaultManager()
        if let directory = fileManager.containerURLForSecurityApplicationGroupIdentifier(groupIdentifier) {
            let path: NSString = directory.path!
            return path.stringByAppendingPathComponent("db.realm")
        } else {
            return RLMRealmConfiguration.defaultConfiguration().fileURL!.path!
        }
    }
    public class func migrateListenItLater() {
        ListenItLaterEntryStore.realm
    }
    public static func realmPath(name: String) -> String {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().fileURL!.path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent(name)
        path = path.stringByAppendingPathExtension("realm")!
        return path as String
    }
    public class func configurationOf(path: String) -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration()
        config.schemaVersion = 5
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
                    if let _ = oldObject, new = newObject {
                        new["likesCount"] = 0
                        new["entries"]    = RLMArray(objectClassName: EntryStore.className())
                        new["likers"]     = RLMArray(objectClassName: ProfileStore.className())
                        new["expiresAt"]  = 0
                    }
                }
            }
        }
        config.fileURL = NSURL(string: "file://\(path)")
        return config
    }
    public class var historyPath: String {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().fileURL!.path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("history")
        path = path.stringByAppendingPathExtension("realm")!
        return path as String
    }

    public class func migrateHistory() {
        HistoryStore.realm
    }
    
    public class var cacheListPath: String {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().fileURL!.path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("cache_list")
        path = path.stringByAppendingPathExtension("realm")!
        return path as String
    }

    public class var cacheSetPath: String {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().fileURL!.path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("cache_map")
        path = path.stringByAppendingPathExtension("realm")!
        return path as String
    }

    public class func migrateCache() {
        EntryCacheList.realm
        TrackCacheSet.realm
    }


    private class func addIdToTrack(migration: RLMMigration) {
        migration.enumerateObjects(TrackStore.className()) { oldObject, newObject in
            if let old = oldObject, new =  newObject {
                let properties = ["title", "streamUrl", "thumbnailUrl"]
                for prop in properties {
                    new[prop] = old[prop]
                }
                new["id"] = "";
            }
        }
    }

    private class func addTimestampsTo(className: String, migration: RLMMigration) {
        var number: Float = 0
        migration.enumerateObjects(className) { oldObject, newObject in
            if let _ = oldObject, new = newObject {
                new["createdAt"] = NSNumber(longLong: NSDate().timestamp)
                new["updatedAt"] = NSNumber(longLong: NSDate().timestamp)
                new["number"]    = NSNumber(float: number)
                number -= 1
            }
        }
    }
}
