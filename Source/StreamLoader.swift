//
//  StreamLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result
import Box

public class StreamLoader {
    public enum RemoveMark {
        case Read
        case Unread
        case Unsave
    }

    public enum State {
        case Normal
        case Fetching
        case Complete
        case Error
    }

    public enum Event {
        case StartLoadingLatest
        case CompleteLoadingLatest
        case StartLoadingNext
        case CompleteLoadingNext
        case FailToLoadNext
        case CompleteLoadingPlaylist(Playlist, Entry)
        case RemoveAt(Int)
    }

    public let feedlyClient = CloudAPIClient.sharedInstance
    let musicfavClient      = MusicFavAPIClient.sharedInstance

    public let stream:             Stream
    public var lastUpdated:        Int64
    public var state:              State
    public var entries:            [Entry]
    public var playlistsOfEntry:   [Entry:Playlist]
    public var loaderOfPlaylist:   [Playlist:(PlaylistLoader, Disposable)]
    public var playlistifier:      Disposable?
    public var streamContinuation: String?
    public var signal:             Signal<Event, NSError>
    public var sink:               SinkOf<ReactiveCocoa.Event<Event, NSError>>

    public init(stream: Stream) {
        self.stream      = stream
        state            = .Normal
        lastUpdated      = 0
        entries          = []
        playlistsOfEntry = [:]
        loaderOfPlaylist = [:]
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
        sink             = pipe.1
    }

    deinit {
        dispose()
    }

    public func dispose() {
        for loader in loaderOfPlaylist {
            loader.1.1.dispose()
        }
        playlistifier?.dispose()
    }

    public func updateLastUpdated(updated: Int64?) {
        if let timestamp = updated {
            self.lastUpdated = timestamp + 1
        } else {
            self.lastUpdated = Int64(NSDate().timeIntervalSince1970 * 1000)
        }
    }

    public var playlists: [Playlist] {
        return entries.map { self.playlistsOfEntry[$0] }
                      .filter { $0 != nil && $0!.validTracksCount > 0 }
                      .map { $0! }
    }

    public func fetchLatestEntries() {
        if entries.count == 0 {
            return
        }

        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId: stream.streamId,
                                          newerThan: lastUpdated,
                                         unreadOnly: unreadOnly)
        sink.put(.Next(Box(.StartLoadingLatest)))
        producer |> startOn(UIScheduler())
               |> start(
                next: { paginatedCollection in
                    var latestEntries = paginatedCollection.items
                    self.playlistifier = latestEntries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                        currentSignal |> concat(nextSignal)
                    }).start(next: {}, error: {error in}, completed: {})
                    latestEntries.extend(self.entries)
                    self.entries = latestEntries
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                    self.sink.put(.Next(Box(.CompleteLoadingLatest)))
            })
    }

    public func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        sink.put(.Next(Box(.StartLoadingNext)))
        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId:stream.streamId, continuation: streamContinuation, unreadOnly: unreadOnly)
        producer |> startOn(UIScheduler())
               |> start(
                next: {paginatedCollection in
                    let entries = paginatedCollection.items
                    self.entries.extend(entries)
                    self.playlistifier = entries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                        currentSignal |> concat(nextSignal)
                    }) |> start(next: {}, error: {error in}, completed: {})
                    self.streamContinuation = paginatedCollection.continuation
                    self.updateLastUpdated(paginatedCollection.updated)
                    self.sink.put(.Next(Box(.CompleteLoadingNext))) // First reload tableView,
                    if paginatedCollection.continuation == nil {    // then wait for next load
                        self.state = .Complete
                    } else {
                        self.state = .Normal
                    }
                },
                error: {error in
                    CloudAPIClient.handleError(error: error)
                    self.state = State.Error
                    self.sink.put(.Next(Box(.FailToLoadNext)))
                },
                completed: {
            })
    }

    public func loadPlaylistOfEntry(entry: Entry) -> SignalProducer<Void, NSError> {
        if let url = entry.url {
            return musicfavClient.playlistify(url, errorOnFailure: false) |> map({ pl in
                var tracks = entry.enclosureTracks
                tracks.extend(pl.getTracks())
                let playlist = Playlist(id: pl.id, title: pl.title, tracks: tracks)
                self.playlistsOfEntry[entry] = playlist
                UIScheduler().schedule {
                    self.sink.put(.Next(Box(.CompleteLoadingPlaylist(playlist, entry))))
                }
                if let _disposable = self.loaderOfPlaylist[playlist] {
                    _disposable.1.dispose()
                }
                let loader = PlaylistLoader(playlist: playlist)
                let disposable = loader.fetchTracks().start(next: { track in
                    }, error: { error in
                        println(error)
                    }, completed: {
                        self.sink.put(.Next(Box(.CompleteLoadingPlaylist(playlist, entry))))
                })
                self.loaderOfPlaylist[playlist] = (loader, disposable)
                return ()
            })
        }
        return SignalProducer<Void, NSError>.empty
    }

    public var unreadOnly: Bool {
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { return false }
            if stream == Tag.Read(userId) {  return false }
        }
        return true
    }

    public var removeMark: RemoveMark {
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { return .Unsave }
            if stream == Tag.Read(userId)  { return .Unread }
        }
        return .Read
    }

    public func markAsRead(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.Next(Box(.RemoveAt(index))))
    }

    public func markAsUnread(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as unread") }
                else             { println("Succeeded in marking as unread") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.Next(Box(.RemoveAt(index))))
    }

    public func markAsUnsaved(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.markEntriesAsUnsaved([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as unsaved") }
                else             { println("Succeeded in marking as unsaved") }
            })
            feedlyClient.markEntriesAsRead([entry.id], completionHandler: { (req, res, error) -> Void in
                if let e = error { println("Failed to mark as read") }
                else             { println("Succeeded in marking as read") }
            })
        }
        entries.removeAtIndex(index)
        sink.put(.Next(Box(.RemoveAt(index))))
    }
}
