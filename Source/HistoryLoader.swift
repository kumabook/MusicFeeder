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
    public var histories: [History] = []
    public var playlistsOfHistory: [History: Playlist] = [:]
    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }
    public convenience init() {
        self.init(stream: SavedStream(id: "history", title: "History"), unreadOnly: false, perPage: CloudAPIClient.perPage)
        reset()
    }

    public convenience init(id: String, title: String) {
        self.init(stream: SavedStream(id: id, title: title), unreadOnly: false, perPage: CloudAPIClient.perPage)
        reset()
    }

    private func reset() {
        self.items      = []
        self.histories  = []
        self.state      = .Normal
    }

    public override func fetchItems() {
        if state != .Normal {
            return
        }
        state = .Fetching
        UIScheduler().schedule {
            let range = 0..<HistoryStore.limit
            let histories: [History] = HistoryStore.find(range).map { History(store: $0) }

            self.histories.appendContentsOf(histories)
            let count = HistoryStore.count()
            dispatch_async(dispatch_get_main_queue()) {
                self.state = .Complete
                self.observer.sendNext(.CompleteLoadingNext)
            }
        }
    }

    public override func fetchPlaylistsOfEntries(entries: [Entry]) {
        self.playlistifier = histories.map {
            self.loadPlaylistOfHistory($0)
        }.reduce(SignalProducer<(Track, Playlist), NSError>.empty, combine: { (currentSignal, nextSignal) in
            currentSignal.concat(nextSignal)
        }).start()
    }

    public override func cancelFetchingPlaylists() {
        playlistifier?.dispose()
    }

    public func loadPlaylistOfHistory(history: History) -> SignalProducer<(Track, Playlist), NSError> {
        if let playlist = self.playlistsOfHistory[history] {
            return SignalProducer<(Track, Playlist), NSError>.empty
                                                            .concat(fetchTracks(playlist).map { _, t in (t, playlist) })
        }
        if let entry = history.entry, url = entry.url {
            if CloudAPIClient.includesTrack {
                let playlist = entry.playlist
                self.playlistsOfHistory[history] = playlist
                self.playlistQueue.enqueue(playlist)
                return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(entry.playlist)
                        .map { _,t in (t, entry.playlist) })
            }
            typealias S = SignalProducer<SignalProducer<(Track, Playlist), NSError>, NSError>
            let signal: S = pinkspiderClient.playlistify(url, errorOnFailure: false).map { pl in
                var tracks = entry.audioTracks
                tracks.appendContentsOf(pl.getTracks())
                let playlist = Playlist(id: pl.id, title: pl.title, tracks: tracks)
                self.playlistsOfHistory[history] = playlist
                self.playlistQueue.enqueue(playlist)
                UIScheduler().schedule {
                    self.observer.sendNext(.CompleteLoadingPlaylist(playlist, entry))
                }
                return SignalProducer<(Track, Playlist), NSError>.empty.concat(self.fetchTracks(playlist)
                                                                       .map { _, t in (t, playlist) })
            }
            return signal.flatten(.Merge)

        } else if let track = history.track {
            let playlist = Playlist(id: "track_history_\(history.timestamp)",
                                    title: track.title ?? "",
                                    tracks: [track])
            self.playlistsOfHistory[history] = playlist
            self.playlistQueue.enqueue(playlist as PlayerKitPlaylist)
            track.fetchDetail().on(next: { track in
                self.playlistQueue.trackUpdated(track)
            }).start()
        }
        return SignalProducer<(Track, Playlist), NSError>.empty
    }

    public override func fetchLatestItems() {
        if state != .Normal {
            return
        }
        reset()
        observer.sendNext(.CompleteLoadingLatest)
        fetchItems()
    }
}