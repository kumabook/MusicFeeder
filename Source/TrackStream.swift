//
//  TrackStream.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/2/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

public class TrackStream: Stream {
    public private(set) var id:    String
    public private(set) var title: String
    public override var streamId: String {
        return id
    }
    public override var streamTitle: String {
        return title
    }

    public init(id: String, title: String) {
        self.id    = id
        self.title = title
    }
}