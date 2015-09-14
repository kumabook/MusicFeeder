//
//  CategoryStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 9/3/15.
//  Copyright (c) 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

extension FeedlyKit.Category {
    internal func toStoreObject() -> CategoryStore {
        if let store = CategoryStore.findBy(id: id) {
            return store
        }
        var store = CategoryStore()
        store.id    = id
        store.label = label
        return store
    }
}

class CategoryStore: RLMObject {
    dynamic var id:        String = ""
    dynamic var label:     String = ""
    internal override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm { return RLMRealm.defaultRealm() }

    internal class func create(category: FeedlyKit.Category) -> PersistentResult {
        if let store = findBy(id: category.id) { return .Failure }
        let store = category.toStoreObject()
        realm.transactionWithBlock() {
            self.realm.addObject(store)
        }
        return .Success
    }

    internal class func save(category: FeedlyKit.Category) -> Bool {
        if let store = findBy(id: category.id) {
            realm.transactionWithBlock() {
                store.label = category.label
            }
            return true
        } else {
            return false
        }
    }

    internal class func findAll() -> [FeedlyKit.Category] {
        var categories: [FeedlyKit.Category] = []
        for store in CategoryStore.allObjectsInRealm(realm) {
            let category: FeedlyKit.Category = FeedlyKit.Category(id: store.id, label: store.label)
            categories.append(category)
        }
        return categories
    }

    internal class func findBy(#id: String) -> CategoryStore? {
        let results = CategoryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? CategoryStore
        }
    }

    internal class func remove(category: FeedlyKit.Category) {
        if let store = findBy(id: category.id) {
            realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    internal class func removeAll() {
        realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }
}
