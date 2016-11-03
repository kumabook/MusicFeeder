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
    func toCacheStoreObject(_ realm: RLMRealm) -> Object
}

public protocol CacheList: class {
    associatedtype Item
    associatedtype Object
    static var realm: RLMRealm { get }
    static var objectClassName: String { get }

    var id:        String   { get }
    var timestamp: Int64    { get set }
    var items:     RLMArray<RLMObject> { get set }
    func add(_ items: [Item]) -> Result<(), NSError>
    func clear() -> Result<(), NSError>
    static func findOrCreate(_ id: String) -> Self
    static func create(_ id: String) -> Self
    static func deleteAllItems()
    static func deleteOldItems()
}

public protocol CacheSet: class {
    associatedtype Item
    associatedtype Object
    associatedtype Entity: CacheEntity
    static var realm: RLMRealm { get }
    static var objectClassName: String { get }

    static func set(_ id: String, item: Item) -> Bool
    static func get(_ id: String) -> Entity?
    static func getAllItems() -> [Entity]
    static func delete(_ id: String) -> Bool
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

    public func add(_ items: [Item]) -> Result<(), NSError> {
        return materialize(try Self.realm.transaction()
            {
                items.forEach {item in
                    let itemCache = item.toCacheStoreObject(Self.realm)
                    Self.realm.addOrUpdate(itemCache)
                    self.items.add(itemCache)
                }
                timestamp = Date().timestamp
                Self.realm.addOrUpdate(self)
            }
        )
    }
    
    public func clear() -> Result<(), NSError> {
        return materialize(try Self.realm.transaction()
            {
                Self.realm.deleteObjects(items)
                Self.realm.delete(self)
            }
        )
    }
    
    public static func findOrCreate(_ id: String) -> Self {
        let results = Self.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return create(id)
        } else {
            return results[0] as! Self
        }
    }
    public static func create(_ id: String) -> Self {
        let list = Self(value: ["id":id])
        let _ = materialize(try realm.transaction()
            {
                Self.realm.addOrUpdate(list)
            })
        return list
    }
    public static func deleteAllItems() {
        let _ = materialize(try realm.transaction()
            {
                realm.deleteObjects(allObjects(in: realm))
            }
        )
    }
    public static func deleteOldItems() {
    }
}

extension CacheSet where Item: Cacheable, Object: RLMObject, Entity: RLMObject, Entity.Object == Object, Item.Object == Object {
    public static var realm: RLMRealm { return try! RLMRealm(configuration: RealmMigration.configurationOf(RealmMigration.cacheSetPath)) }

    public static func set(_ id: String, item: Item) -> Bool {
        switch materialize(try realm.transaction()
            {
                let entity       = Entity(value: ["id": id])
                let itemCache    = item.toCacheStoreObject(Self.realm)
                Self.realm.addOrUpdate(itemCache)
                entity.timestamp = Date().timestamp
                entity.item = itemCache
                Self.realm.addOrUpdate(entity)
            })
        {
        case .success: return true
        case .failure: return false
        }
    }
    public static func get(_ id: String) -> Entity? {
        let results = Entity.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? Entity
        }
    }
    public static func getAllItems() -> [Entity] {
        return realizeResults(Entity.allObjects(in: realm)).map { $0 as! Entity }
    }
    public static func delete(_ id: String) -> Bool {
        guard let obj = get(id) else { return false }
        switch materialize(try realm.transaction()
            {
                Self.realm.delete(obj)
            }
        ) {
        case .success: return true
        case .failure: return false
        }
    }
    public static func deleteAllItems() {
       let _ =  materialize(try realm.transaction()
            {
                Self.realm.deleteAllObjects()
            })
    }
    public static func deleteOldItems() {
    }
}

