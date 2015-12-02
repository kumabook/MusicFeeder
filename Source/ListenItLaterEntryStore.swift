//
//  ListenItLaterEntryStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 12/2/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

public class ListenItLaterEntryStore: EntryStore {
    static var groupIdentifier: String = "group.com.kumabook.MusicFav"
    override class var realm: RLMRealm {
        get {
            let fileManager = NSFileManager.defaultManager()
            let directory = fileManager.containerURLForSecurityApplicationGroupIdentifier(groupIdentifier)!
            let path: NSString = directory.path!
            let realmPath = path.stringByAppendingPathComponent("db.realm")
            return RLMRealm(path: realmPath as String)
        }
    }

    public class func moveToSaved() {
        let entryStores = findAll()
        entryStores.forEach {
            print("add \($0.id)")
            EntryStore.create(Entry(store: $0))
        }
        removeAll()
    }
}