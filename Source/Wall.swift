//
//  Wall.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/17.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import FeedlyKit

public struct Wall: ResponseObjectSerializable {
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    public var id:        String
    public var label:     String
    public var resources: [Resource]
    
    public init(id: String, label: String, resources: [Resource]) {
        self.id        = id
        self.label     = label
        self.resources = resources
    }

    public init(json: JSON) {
        id        = json["id"].stringValue
        label     = json["label"].stringValue
        resources = json["resources"].arrayValue.map { Resource(json: $0) }
    }
}
