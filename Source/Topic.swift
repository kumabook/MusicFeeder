//
//  Topic.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/29/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit
import SwiftyJSON

public final class Topic: FeedlyKit.Stream, ResponseObjectSerializable, ResponseCollectionSerializable, ParameterEncodable {
    public fileprivate(set) var id:          String
    public fileprivate(set) var label:       String
    public fileprivate(set) var description: String?

    public override var streamId: String {
        return id
    }

    public override var streamTitle: String {
        return label
    }

    public class func collection(_ response: HTTPURLResponse, representation: Any) -> [Topic]? {
        let json = JSON(representation)
        return json.arrayValue.map({ Topic(json: $0) })
    }

    @objc required public convenience init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    public init(json: JSON) {
        id          = json["id"].stringValue
        label       = json["label"].stringValue
        description = json["description"].string
    }

    public init(label: String, description: String? = nil) {
        self.id          = "topic/\(label)"
        self.label       = label
        self.description = description
    }

    public init(store: TopicStore) {
        id          = store.id
        label       = store.label
        description = store.desc
    }

    public func toStoreObject() -> TopicStore {
        let store    = TopicStore()
        store.id     = id
        store.label  = label
        store.desc   = description ?? ""
        return store
    }

    public func toParameters() -> [String : Any] {
        if let d = description {
            return ["id": id as AnyObject, "label": label, "description": d]
        } else {
            return ["id": id as AnyObject, "label": label]
        }
    }
}


