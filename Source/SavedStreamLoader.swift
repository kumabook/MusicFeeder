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

public class SavedStream: Stream {
    let id:    String
    let title: String

    init(id: String, title: String) {
        self.id    = id
        self.title = title
    }
    override public var streamId: String {
        return id
    }
    override public var streamTitle: String {
        return title
    }
    override public var thumbnailURL: NSURL? {
        return nil
    }
    override public var hashValue: Int {
        return streamId.hashValue
    }
}

public class SavedStreamLoader: StreamLoader {
    public convenience init() {
        self.init(stream: SavedStream(id: "saved_stream", title: "Saved"))
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title))
    }

    public override func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        QueueScheduler().schedule {
            let entries: [Entry] = EntryStore.findAll().map { Entry(store: $0) }.reverse()
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