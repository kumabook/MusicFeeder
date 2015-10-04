//
//  SavedStreamLoader.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/4/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class SavedStreamLoader: StreamLoader {
    public class SavedStream: Stream {
        override public var streamId: String {
            return "saved_stream"
        }
        override public var streamTitle: String {
            return "Clipped Entries"
        }
        override public var thumbnailURL: NSURL? {
            return nil
        }
        override public var hashValue: Int {
           return streamId.hashValue
        }
    }

    public convenience init() {
        self.init(stream: SavedStream())
    }

    public override func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        QueueScheduler().schedule {
            let entries = EntryStore.findAll().map { Entry(store: $0) }
            self.playlistifier = entries.map({
                self.loadPlaylistOfEntry($0)
            }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                currentSignal.concat(nextSignal)
            }).on(next: {}, error: {error in}, completed: {}).start()
            self.entries = entries
            UIScheduler().schedule {
                self.state = .Complete
                self.sink(.Next(.CompleteLoadingLatest))
            }
        }
    }

    public override func fetchLatestEntries() {
        fetchEntries()
    }

}