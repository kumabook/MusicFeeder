//
//  TopicStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/12/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import Realm

open class TopicStore: RLMObject {
    open dynamic var id:          String = ""
    open dynamic var label:       String = ""
    open dynamic var desc:        String = ""
    open override class func primaryKey() -> String {
        return "id"
    }
    open override class func requiredProperties() -> [String] {
        return ["id", "label"]
    }
}
