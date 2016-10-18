//
//  Cacheable.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/12/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation

import Realm
import FeedlyKit
import Result

public protocol Cacheable {
    associatedtype Object
    var id: String { get }
    func toCacheStoreObject() -> Object
}

public protocol CacheList: class {
    associatedtype Item
    associatedtype Object
    static var realm: RLMRealm { get }
    static var objectClassName: String { get }

    var id:        String   { get }
    var timestamp: Int64    { get set }
    var items:     RLMArray { get set }
    func add(items: [Item]) -> Result<(), NSError>
    func clear() -> Result<(), NSError>
    static func findOrCreate(id: String) -> Self
    static func create(id: String) -> Self
    static func deleteAllItems()
    static func deleteOldItems()
}

public protocol CacheMap: class {
    associatedtype Item
    associatedtype Object
    associatedtype Entity: CacheEntity
    static var realm: RLMRealm { get }
    static var objectClassName: String { get }

    static func set(id: String, item: Item) -> Bool
    static func get(id: String) -> Entity?
    static func getAllItems() -> [Entity]
    static func delete(id: String) -> Bool
    static func deleteAllItems()
    static func deleteOldItems()
}

public protocol CacheEntity: class {
    associatedtype Object
    var id:        String  { get }
    var timestamp: Int64   { get set }
    var item:      Object? { get set }
}

extension CacheList where Self: RLMObject, Item: Cacheable, Object: RLMObject, Item.Object == Object {
    public static var realm: RLMRealm { return try! RLMRealm(configuration: RealmMigration.configurationOf(RealmMigration.cacheListPath)) }

    public func add(items: [Item]) -> Result<(), NSError> {
        return materialize(try Self.realm.transactionWithBlock()
            {
                items.forEach {item in
                    let results = Object.objectsInRealm(Self.realm, withPredicate: NSPredicate(format: "id= %@", item.id))
                    if results.count == 0 {
                        self.items.addObject(item.toCacheStoreObject())
                    } else {
                        self.items.addObject(results[0] as! Object)
                    }
                }
                timestamp = NSDate().timestamp
                Self.realm.addOrUpdateObject(self)
            }
        )
    }
    
    public func clear() -> Result<(), NSError> {
        return materialize(try Self.realm.transactionWithBlock()
            {
                Self.realm.deleteObjects(items)
                Self.realm.deleteObject(self)
            }
        )
    }
    
    public static func findOrCreate(id: String) -> Self {
        let results = Self.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return create(id)
        } else {
            return results[0] as! Self
        }
    }
    public static func create(id: String) -> Self {
        let list = Self(value: ["id":id])
        materialize(try realm.transactionWithBlock()
            {
                Self.realm.addOrUpdateObject(list)
            })
        return list
    }
    public static func deleteAllItems() {
        materialize(try realm.transactionWithBlock()
            {
                realm.deleteObjects(allObjectsInRealm(realm))
            }
        )
    }
    public static func deleteOldItems() {
    }
}

extension CacheMap where Item: Cacheable, Object: RLMObject, Entity: RLMObject, Entity.Object == Object, Item.Object == Object {
    public static var realm: RLMRealm { return try! RLMRealm(configuration: RealmMigration.configurationOf(RealmMigration.cacheMapPath)) }

    public static func set(id: String, item: Item) -> Bool {
        switch materialize(try realm.transactionWithBlock()
            {
                let entity       = Entity(value: ["id": id])
                entity.timestamp = NSDate().timestamp
                let results = Object.objectsInRealm(Self.realm, withPredicate: NSPredicate(format: "id= %@", item.id))
                if results.count == 0 {
                    entity.item = item.toCacheStoreObject()
                } else {
                    entity.item = results[0] as? Object
                }
                Self.realm.addOrUpdateObject(entity)
            })
        {
        case .Success: return true
        case .Failure: return false
        }
    }
    public static func get(id: String) -> Entity? {
        let results = Entity.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? Entity
        }
    }
    public static func getAllItems() -> [Entity] {
        return Entity.allObjectsInRealm(realm).map { $0 as! Entity }
    }
    public static func delete(id: String) -> Bool {
        guard let obj = get(id) else { return false }
        switch materialize(try realm.transactionWithBlock()
            {
                Self.realm.deleteObject(obj)
            }
        ) {
        case .Success: return true
        case .Failure: return false
        }
    }
    public static func deleteAllItems() {
        materialize(try realm.transactionWithBlock()
            {
                Self.realm.deleteAllObjects()
            })
    }
    public static func deleteOldItems() {
    }
}

