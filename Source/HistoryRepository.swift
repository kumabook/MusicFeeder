//
//  HistoryRepository.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/26/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift

import FeedlyKit

open class HistoryRepository: EntryRepository {
    open var histories: [History] = []
    open var playlistsOfHistory: [History: Playlist] = [:]
    public override init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
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

    fileprivate func reset() {
        self.items      = []
        self.histories  = []
        self.state      = .normal
    }

    open override func fetchItems() {
        if state != .normal {
            return
        }
        state = .fetching
        UIScheduler().schedule {
            let range = 0..<HistoryStore.limit
            let histories: [History] = HistoryStore.find(range).map { History(store: $0) }

            self.histories.append(contentsOf: histories)
            DispatchQueue.main.async() {
                self.state = .complete
                self.observer.send(value: .completeLoadingNext)
            }
        }
    }

    open override func fetchPlaylistsOfEntries(_ entries: [Entry]) {
        self.playlistifier = histories.map {
            self.loadPlaylistOfHistory($0)
        }.reduce(SignalProducer<(Track, Playlist), NSError>.empty, { (currentSignal, nextSignal) in
            currentSignal.concat(nextSignal)
        }).start()
    }

    open override func cancelFetchingPlaylists() {
        playlistifier?.dispose()
    }

    open func loadPlaylistOfHistory(_ history: History) -> SignalProducer<(Track, Playlist), NSError> {
        if let playlist = self.playlistsOfHistory[history] {
            return SignalProducer<(Track, Playlist), NSError>.empty
                                                            .concat(fetchTracks(playlist).map { _, t in (t, playlist) })
        }
        if let entry = history.entry, let url = entry.url {
            if CloudAPIClient.includesTrack {
                let playlist = entry.toPlaylist()
                self.playlistsOfHistory[history] = playlist
                self.playlistQueue.enqueue(playlist)
                return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(playlist)
                        .map { _,t in (t, playlist) })
            }
            typealias S = SignalProducer<SignalProducer<(Track, Playlist), NSError>, NSError>
            let signal: S = pinkspiderClient.playlistify(url, errorOnFailure: false).map { pl in
                var tracks = entry.audioTracks
                tracks.append(contentsOf: pl.getTracks())
                let playlist = Playlist(id: pl.id, title: pl.title, tracks: tracks)
                self.playlistsOfHistory[history] = playlist
                self.playlistQueue.enqueue(playlist)
                UIScheduler().schedule {
                    self.observer.send(value: .completeLoadingPlaylist(playlist, entry))
                }
                return SignalProducer<(Track, Playlist), NSError>.empty.concat(self.fetchTracks(playlist)
                                                                       .map { _, t in (t, playlist) })
            }
            return signal.flatten(.merge)

        } else if let track = history.track {
            let playlist = Playlist(id: "track_history_\(history.timestamp)",
                                    title: track.title ?? "",
                                    tracks: [track])
            self.playlistsOfHistory[history] = playlist
            self.playlistQueue.enqueue(playlist as PlayerKitPlaylist)
            track.fetchDetail().on(value: { track in
                self.playlistQueue.trackUpdated(track)
            }).start()
        }
        return SignalProducer<(Track, Playlist), NSError>.empty
    }

    open override func fetchLatestItems() {
        if state != .normal {
            return
        }
        reset()
        observer.send(value: .completeLoadingLatest)
        fetchItems()
    }
}
