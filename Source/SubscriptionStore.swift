//
//  StreamStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 9/3/15.
//  Copyright (c) 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

extension Subscription {
    internal func toStoreObject() -> SubscriptionStore {
        let store       = SubscriptionStore()
        store.id        = streamId
        store.title     = streamTitle
        store.visualUrl = visualUrl ?? ""
        store.categories.addObjects(categories.map { $0.toStoreObject() })
        return store
    }
    public class func findAll(orderBy: OrderBy = OrderBy.Number(.Desc)) -> [Subscription] {
        var subscriptions: [Subscription] = []
        var categories: [FeedlyKit.Category] = []
        for store in SubscriptionStore.findAll(orderBy) {
            for c in store.categories {
                if let categoryStore: CategoryStore = c as? CategoryStore {
                    categories.append(FeedlyKit.Category(id: categoryStore.id, label: categoryStore.label))
                }
            }
            let subscription: Subscription = Subscription(id: store.id,
                                                       title: store.title,
                                                   visualUrl: store.visualUrl,
                                                  categories: categories)
            subscriptions.append(subscription)
        }
        return subscriptions
    }
}

public class SubscriptionStore: RLMObject {
    static var sharedOrderBy: OrderBy = OrderBy.Number(.Desc)
    public dynamic var id:         String = ""
    public dynamic var title:      String = ""
    public dynamic var visualUrl:  String?
    public dynamic var categories = RLMArray(objectClassName: CategoryStore.className())
    public dynamic var createdAt:  Int64  = 0
    public dynamic var updatedAt:  Int64  = 0
    public dynamic var lastReadAt: Int64  = 0
    public dynamic var number:     Float  = 0
    public override class func primaryKey() -> String {
        return "id"
    }

    public override class func requiredProperties() -> [String] {
        return ["id", "title"]
    }

    class var realm: RLMRealm { return RLMRealm.defaultRealm() }

    public func updateLastReadAt() -> PersistentResult {
        try! SubscriptionStore.realm.transactionWithBlock() {
            lastReadAt = NSDate().timestamp
        }
        return .Success
    }

    public class func create(subscription: Subscription) -> PersistentResult {
        if let _ = findBy(id: subscription.streamId) { return .Failure }
        let store = subscription.toStoreObject()
        store.createdAt = NSDate().timestamp
        store.updatedAt = NSDate().timestamp
        store.number    = Float(findAll().count)
        try! realm.transactionWithBlock() {
            self.realm.addObject(store)
        }
        return .Success
    }

    public class func save(subscription: Subscription) -> Bool {
        if let store = findBy(id: subscription.streamId) {
            try! realm.transactionWithBlock() {
                store.title = subscription.streamTitle
            }
            return true
        } else {
            return false
        }
    }

    public class func findAll(orderBy: OrderBy = OrderBy.Number(.Desc)) -> RLMResults {
        return SubscriptionStore.allObjectsInRealm(realm).sortedResultsUsingProperty(orderBy.name, ascending: orderBy.ascending)
    }

    public class func findBy(id id: String) -> SubscriptionStore? {
        let results = SubscriptionStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? SubscriptionStore
        }
    }

    public class func remove(stream: Subscription) {
        if let store = findBy(id: stream.streamId) {
            try! realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    public class func removeAll() {
        try! realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }

    public class func moveSubscriptionInSharedList(sourceIndex: Int, toIndex: Int) -> PersistentResult {
        let storeList  = findAll()
        guard let source = findBy(id: storeList[UInt(sourceIndex)].id) else { return .Failure }
        let destNumber = storeList[UInt(toIndex)].number
        var nextIndex  = toIndex
        var direction  = 0 as Float
        if toIndex > sourceIndex {
            nextIndex += 1
            direction = sharedOrderBy.ascending ? 1 : -1
        } else if toIndex < sourceIndex {
            nextIndex -= 1
            direction = sharedOrderBy.ascending ? -1 : 1
        }
        try! realm.transactionWithBlock() {
            if 0 <= nextIndex && nextIndex < Int(storeList.count) {
                let next = storeList[UInt(nextIndex)]
                source.number = (destNumber + next.number) / 2
            } else {
                source.number = destNumber + direction
            }
        }
        return .Success
    }
}
