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
    override class var realm: RLMRealm {
        return try! RLMRealm(configuration: RealmMigration.listenItLaterConfiguration())
    }

    public class func moveToSaved() {
        let entryStores = findAll()
        entryStores.forEach {
            EntryStore.create(Entry(store: $0))
        }
        removeAll()
    }
}