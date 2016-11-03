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
    public class func findAll() -> [FeedlyKit.Category] {
        var categories: [FeedlyKit.Category] = []
        for store in realizeResults(CategoryStore.findAll()) {
            let category: FeedlyKit.Category = FeedlyKit.Category(id: store.id, label: store.label)
            categories.append(category)
        }
        return categories
    }
}

open class CategoryStore: RLMObject {
    dynamic var id:        String = ""
    dynamic var label:     String = ""
    open override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm { return RLMRealm.default() }

    open class func create(_ category: FeedlyKit.Category) -> PersistentResult {
        if let _ = findBy(id: category.id) { return .failure }
        let store = category.toStoreObject()
        try! realm.transaction() {
            self.realm.add(store)
        }
        return .success
    }

    open class func save(_ category: FeedlyKit.Category) -> Bool {
        if let store = findBy(id: category.id) {
            try! realm.transaction() {
                store.label = category.label
            }
            return true
        } else {
            return false
        }
    }

    open class func findAll() -> RLMResults<CategoryStore> {
        return CategoryStore.allObjects(in: realm) as! RLMResults<CategoryStore>
    }

    open class func findBy(id: String) -> CategoryStore? {
        let results = CategoryStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? CategoryStore
        }
    }

    open class func remove(_ category: FeedlyKit.Category) {
        if let store = findBy(id: category.id) {
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
}
