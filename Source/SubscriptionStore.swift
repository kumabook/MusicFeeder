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
}

class SubscriptionStore: RLMObject {
    dynamic var id:         String = ""
    dynamic var title:      String = ""
    dynamic var visualUrl:  String = ""
    dynamic var categories = RLMArray(objectClassName: CategoryStore.className())
    internal override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm { return RLMRealm.defaultRealm() }

    internal class func create(subscription: Subscription) -> PersistentResult {
        if let store = findBy(id: subscription.streamId) { return .Failure }
        let store = subscription.toStoreObject()
        realm.transactionWithBlock() {
            self.realm.addObject(store)
        }
        return .Success
    }

    internal class func save(subscription: Subscription) -> Bool {
        if let store = findBy(id: subscription.streamId) {
            realm.transactionWithBlock() {
                store.title = subscription.streamTitle
            }
            return true
        } else {
            return false
        }
    }

    internal class func findAll() -> [Subscription] {
        var subscriptions: [Subscription] = []
        for store in SubscriptionStore.allObjectsInRealm(realm) {
            var categories = [] as [FeedlyKit.Category]
            for c in store.categories {
                if let categoryStore = c as? CategoryStore {
                    categories.append(FeedlyKit.Category(id: categoryStore.id, label: categoryStore.label))
                }
            }
            let subscription = Subscription(id: store.id,
                                         title: store.title,
                                     visualUrl: store.visualUrl,
                                    categories: categories)
            subscriptions.append(subscription)
        }
        return subscriptions
    }

    internal class func findBy(#id: String) -> SubscriptionStore? {
        let results = SubscriptionStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? SubscriptionStore
        }
    }

    internal class func remove(stream: Subscription) {
        if let store = findBy(id: stream.streamId) {
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
