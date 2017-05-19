//
//  JSONCache.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/19.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit
import SwiftyJSON
import Result

public class JSONItem: Cacheable {
    public typealias Object = JSONObject
    public var id:    String    = ""
    public var value: String = ""
    public init(id: String, value: String) {
        self.id    = id
        self.value = value
    }
    public func toCacheStoreObject(_ realm: RLMRealm) -> JSONObject {
        return JSONObject(value: ["id": id, "value": value])
    }
}


public class JSONObject: RLMObject {
    public dynamic var id:    String = ""
    public dynamic var value: String = ""
    public override class func primaryKey() -> String {
        return "id"
    }
    public override class func requiredProperties() -> [String] {
        return ["id", "value"]
    }
}

public final class JSONCacheSet: RLMObject, CacheSet {
    public typealias Item   = JSONItem
    public typealias Object = JSONObject
    public typealias Entity = JSONCacheEntity
    public static var objectClassName: String { return JSONObject.className() }
    public override class func requiredProperties() -> [String] {
        return ["id"]
    }
}

public final class JSONCacheEntity: RLMObject, CacheEntity {
    public typealias Object = JSONObject
    dynamic public var id:        String   = ""
    dynamic public var timestamp: Int64    = 0
    dynamic public var item:      JSONObject?
    public override class func primaryKey() -> String {
        return "id"
    }
    public override class func requiredProperties() -> [String] {
        return ["id"]
    }
}
