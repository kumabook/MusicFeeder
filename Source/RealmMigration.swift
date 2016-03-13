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
    }

    public class func mainConfiguration() -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration.defaultConfiguration()
        config.schemaVersion = 8
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
            return RLMRealmConfiguration.defaultConfiguration().path!
        }
    }

    public class func listenItLaterConfiguration() -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration()
        config.schemaVersion = 1
        config.migrationBlock = { migration, oldVersion in
            if (oldVersion < 1) {
                migration.enumerateObjects(ListenItLaterEntryStore.className()) { oldObject, newObject in }
            }
        }
        config.path = listenItLaterPath
        return config
    }

    public class func migrateListenItLater() {
        ListenItLaterEntryStore.realm
    }

    public class var historyPath: String {
        var path: NSString = RLMRealmConfiguration.defaultConfiguration().path!
        path = path.stringByDeletingLastPathComponent
        path = path.stringByAppendingPathComponent("history")
        path = path.stringByAppendingPathExtension("realm")!
        return path as String
    }

    public class func historyConfiguration() -> RLMRealmConfiguration {
        let config = RLMRealmConfiguration()
        config.schemaVersion = 1
        config.migrationBlock = { migration, oldVersion in
            if (oldVersion < 1) {
                migration.enumerateObjects(EntryStore.className())   { oldObject, newObject in }
                migration.enumerateObjects(TrackStore.className())   { oldObject, newObject in }
                migration.enumerateObjects(HistoryStore.className()) { oldObject, newObject in }
            }
        }
        config.path = historyPath
        return config
    }

    public class func migrateHistory() {
        HistoryStore.realm
    }
}