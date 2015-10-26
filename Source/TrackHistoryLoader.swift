//
//  TrackHistoryLoader.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class TrackHistoryLoader: StreamLoader {
    var offset: UInt = 0
    public var histories: [TrackHistory] = []
    public convenience init() {
        self.init(stream: SavedStream(id: "track_history", title: "TrackHistory"))
        reset()
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title))
        reset()
    }

    private func reset() {
        self.offset           = 0
        self.entries          = []
        self.histories        = []
        self.state            = .Normal
    }

    public override func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        UIScheduler().schedule {
            let range = Range<UInt>(start: self.offset, end: self.offset + TrackHistoryStore.limit)
            let histories = TrackHistoryStore.find(range)
            self.offset += TrackHistoryStore.limit
            self.histories.appendContentsOf(histories.map { TrackHistory(store: $0) })
            let count = TrackHistoryStore.count()
            dispatch_async(dispatch_get_main_queue()) {
                if self.offset >= count {
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                self.sink(.Next(.CompleteLoadingNext))
            }
        }
    }

    public override func fetchLatestEntries() {
        if state != .Normal {
            return
        }
        reset()
        self.sink(.Next(.CompleteLoadingLatest))
        fetchEntries()
    }
}