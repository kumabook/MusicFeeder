//
//  TopicStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/12/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import Realm

public class TopicStore: RLMObject {
    public dynamic var id:          String = ""
    public dynamic var label:       String = ""
    public dynamic var desc:        String = ""
    public override class func primaryKey() -> String {
        return "id"
    }
    public override class func requiredProperties() -> [String] {
        return ["id", "label"]
    }
}