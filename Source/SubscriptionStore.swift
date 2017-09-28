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
        store.categories.addObjects(categories.map { $0.toStoreObject() } as NSArray)
        return store
    }
    public class func findAll(_ orderBy: OrderBy = OrderBy.number(.desc)) -> [Subscription] {
        var subscriptions: [Subscription] = []
        var categories: [FeedlyKit.Category] = []
        for store in realizeResults(SubscriptionStore.findAll(orderBy)) {
            for c in realize(store.categories) {
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

open class SubscriptionStore: RLMObject {
    static var sharedOrderBy: OrderBy = OrderBy.number(.desc)
    @objc open dynamic var id:         String = ""
    @objc open dynamic var title:      String = ""
    @objc open dynamic var visualUrl:  String?
    @objc open dynamic var categories = RLMArray(objectClassName: CategoryStore.className())
    @objc open dynamic var createdAt:  Int64  = 0
    @objc open dynamic var updatedAt:  Int64  = 0
    @objc open dynamic var lastReadAt: Int64  = 0
    @objc open dynamic var number:     Float  = 0
    open override class func primaryKey() -> String {
        return "id"
    }

    open override class func requiredProperties() -> [String] {
        return ["id", "title"]
    }

    class var realm: RLMRealm { return RLMRealm.default() }

    open func updateLastReadAt() -> PersistentResult {
        try! SubscriptionStore.realm.transaction() {
            lastReadAt = Date().timestamp
        }
        return .success
    }

    open class func create(_ subscription: Subscription) -> PersistentResult {
        if let _ = findBy(id: subscription.streamId) { return .failure }
        let store = subscription.toStoreObject()
        store.createdAt = Date().timestamp
        store.updatedAt = Date().timestamp
        store.number    = Float(findAll().count)
        try! realm.transaction() {
            self.realm.add(store)
        }
        return .success
    }

    open class func save(_ subscription: Subscription) -> Bool {
        if let store = findBy(id: subscription.streamId) {
            try! realm.transaction() {
                store.title = subscription.streamTitle
            }
            return true
        } else {
            return false
        }
    }

    open class func findAll(_ orderBy: OrderBy = OrderBy.number(.desc)) -> RLMResults<SubscriptionStore> {
        return SubscriptionStore.allObjects(in: realm).sortedResults(usingKeyPath: orderBy.name, ascending: orderBy.ascending) as! RLMResults<SubscriptionStore>
    }

    open class func findBy(id: String) -> SubscriptionStore? {
        let results = SubscriptionStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? SubscriptionStore
        }
    }

    open class func remove(_ stream: Subscription) {
        if let store = findBy(id: stream.streamId) {
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

    open class func moveSubscriptionInSharedList(_ sourceIndex: Int, toIndex: Int) -> PersistentResult {
        let storeList  = findAll()
        guard let source = findBy(id: storeList[UInt(sourceIndex)].id) else { return .failure }
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
        try! realm.transaction() {
            if 0 <= nextIndex && nextIndex < Int(storeList.count) {
                let next = storeList[UInt(nextIndex)]
                source.number = (destNumber + next.number) / 2
            } else {
                source.number = destNumber + direction
            }
        }
        return .success
    }
}
