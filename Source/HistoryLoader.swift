//
//  HistoryLoader.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class HistoryLoader: StreamLoader {
    var offset: UInt = 0
    public var histories: [History] = []
    public var playlistsOfHistory: [History: Playlist] = [:]
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
        self.histories        = []
        self.state            = .Normal
    }

    public override func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        UIScheduler().schedule {
            let range = Range<UInt>(start: self.offset, end: self.offset + HistoryStore.limit)
            let histories: [History] = HistoryStore.find(range).map { History(store: $0) }

            self.offset += HistoryStore.limit

            self.playlistifier = histories.map({
                self.loadPlaylistOfHistory($0)
            }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                currentSignal.concat(nextSignal)
            }).start()

            self.histories.appendContentsOf(histories)
            let count = HistoryStore.count()
            dispatch_async(dispatch_get_main_queue()) {
                if self.offset >= count {
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                self.observer.sendNext(.CompleteLoadingNext)
            }
        }
    }

    public func loadPlaylistOfHistory(history: History) -> SignalProducer<Void, NSError> {
        if let entry = history.entry, url = entry.url {
            if CloudAPIClient.includesTrack {
                let playlist = entry.playlist
                self.playlistsOfHistory[history] = playlist
                UIScheduler().schedule {
                    self.observer.sendNext(.CompleteLoadingPlaylist(playlist, entry))
                }
                self.fetchTracks(entry.playlist, entry: entry)
                return SignalProducer<Void, NSError>.empty
            } else {
                return musicfavClient.playlistify(url, errorOnFailure: false).map({ pl in
                    var tracks = entry.audioTracks
                    tracks.appendContentsOf(pl.getTracks())
                    let playlist = Playlist(id: pl.id, title: pl.title, tracks: tracks)
                    self.playlistsOfHistory[history] = playlist
                    UIScheduler().schedule {
                        self.observer.sendNext(.CompleteLoadingPlaylist(playlist, entry))
                    }
                    self.fetchTracks(playlist, entry: entry)
                    return ()
                })
            }
        } else if let track = history.track {
            self.playlistsOfHistory[history] = Playlist(id: "track_history_\(history.timestamp)",
                                                     title: track.title ?? "",
                                                    tracks: [track])
            track.fetchDetail().start()
        }
        return SignalProducer<Void, NSError>.empty
    }

    public override func fetchLatestEntries() {
        if state != .Normal {
            return
        }
        reset()
        observer.sendNext(.CompleteLoadingLatest)
        fetchEntries()
    }
}