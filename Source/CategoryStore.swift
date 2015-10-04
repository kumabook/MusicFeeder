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
    public convenience init(store: CategoryStore) {
        self.init(id: store.id, label: store.label)
    }
    internal func toStoreObject() -> CategoryStore {
        if let store = CategoryStore.findBy(id: id) {
            return store
        }
        let store = CategoryStore()
        store.id    = id
        store.label = label
        return store
    }
}

public class CategoryStore: RLMObject {
    dynamic var id:        String = ""
    dynamic var label:     String = ""
    public override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm { return RLMRealm.defaultRealm() }

    public class func create(category: FeedlyKit.Category) -> PersistentResult {
        if let _ = findBy(id: category.id) { return .Failure }
        let store = category.toStoreObject()
        realm.transactionWithBlock() {
            self.realm.addObject(store)
        }
        return .Success
    }

    public class func save(category: FeedlyKit.Category) -> Bool {
        if let store = findBy(id: category.id) {
            realm.transactionWithBlock() {
                store.label = category.label
            }
            return true
        } else {
            return false
        }
    }

    public class func findAll() -> [FeedlyKit.Category] {
        var categories: [FeedlyKit.Category] = []
        for store in CategoryStore.allObjectsInRealm(realm) {
            let category: FeedlyKit.Category = FeedlyKit.Category(id: store.id, label: store.label)
            categories.append(category)
        }
        return categories
    }

    public class func findBy(id id: String) -> CategoryStore? {
        let results = CategoryStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? CategoryStore
        }
    }

    public class func remove(category: FeedlyKit.Category) {
        if let store = findBy(id: category.id) {
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
