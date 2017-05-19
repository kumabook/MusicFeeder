//
//  Journal.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/2/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit
import SwiftyJSON

public final class Journal: FeedlyKit.Stream {
    public fileprivate(set) var id:          String
    public fileprivate(set) var label:       String
    public fileprivate(set) var description: String?

    public override var streamId: String {
        return id
    }

    public override var streamTitle: String {
        return label
    }
    public init(label: String, description: String? = nil) {
        self.id          = "journal/\(label)"
        self.label       = label
        self.description = description
    }
    public init(json: JSON) {
        id          = json["id"].stringValue
        label       = json["label"].stringValue
        description = json["description"].string
    }
}
