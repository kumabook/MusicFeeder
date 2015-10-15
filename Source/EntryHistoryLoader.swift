//
//  EntryHistoryLoader.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/12/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class EntryHistoryLoader: StreamLoader {
    var offset: UInt = 0
    public var historyOfEntry: [Entry: EntryHistoryStore] = [:]
    public convenience init() {
        self.init(stream: SavedStream(id: "history", title: "History"))
        reset()
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title))
        reset()
    }

    private func reset() {
        self.offset           = 0
        self.entries          = []
        self.historyOfEntry   = [:]
        self.state            = .Normal
    }

    public override func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        QueueScheduler().schedule {
            let range = Range<UInt>(start: self.offset, end: self.offset + EntryHistoryStore.limit)
            let histories = EntryHistoryStore.find(range)
            let entries = histories.map { Entry(store: $0.entry) }
            for h in histories {
                self.historyOfEntry[Entry(store: h.entry)] = h
            }
            self.offset += EntryHistoryStore.limit
            self.playlistifier = entries.map({
                self.loadPlaylistOfEntry($0)
            }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                currentSignal.concat(nextSignal)
            }).on(next: {}, error: {error in}, completed: {}).start()
            self.entries.appendContentsOf(entries)
            dispatch_async(dispatch_get_main_queue()) {
                if self.offset >= EntryHistoryStore.count() {
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