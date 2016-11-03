//
//  TrackStream.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/2/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

open class TrackStream: FeedlyKit.Stream {
    open fileprivate(set) var id:    String
    open fileprivate(set) var title: String
    open override var streamId: String {
        return id
    }
    open override var streamTitle: String {
        return title
    }

    public init(id: String, title: String) {
        self.id    = id
        self.title = title
    }
}
