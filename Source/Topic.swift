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

public final class Topic: Stream, ResponseObjectSerializable, ResponseCollectionSerializable, ParameterEncodable {
    public private(set) var id:          String
    public private(set) var label:       String
    public private(set) var description: String?

    public override var streamId: String {
        return id
    }

    public override var streamTitle: String {
        return label
    }

    public class func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [Topic]? {
        let json = JSON(representation)
        return json.arrayValue.map({ Topic(json: $0) })
    }

    @objc required public convenience init?(response: NSHTTPURLResponse, representation: AnyObject) {
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

    public func toParameters() -> [String : AnyObject] {
        if let d = description {
            return ["id": id, "label": label, "description": d]
        } else {
            return ["id": id, "label": label]
        }
    }
}


