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
    public var sink:               Signal<Event, NSError>.Observer

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
        sink(.Next(.StartLoadingLatest))
        producer
            .startOn(UIScheduler())
            .on(
                next: { paginatedCollection in
                    var latestEntries = paginatedCollection.items
                    self.playlistifier = latestEntries.map({
                        self.loadPlaylistOfEntry($0)
                    }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                        currentSignal.concat(nextSignal)
                    }).on(next: {}, error: {error in}, completed: {}).start()
                    latestEntries.appendContentsOf(self.entries)
                    self.entries = latestEntries
                    self.updateLastUpdated(paginatedCollection.updated)
                },
                error: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                    self.sink(.Next(.CompleteLoadingLatest))
            }).start()
    }

    public func fetchEntries() {
        if state != .Normal {
            return
        }
        state = .Fetching
        sink(.Next(.StartLoadingNext))
        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId:stream.streamId, continuation: streamContinuation, unreadOnly: unreadOnly)
        producer
            .startOn(UIScheduler())
            .on(next: {paginatedCollection in
                let entries = paginatedCollection.items
                self.entries.appendContentsOf(entries)
                self.playlistifier = entries.map({
                    self.loadPlaylistOfEntry($0)
                }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
                    currentSignal.concat(nextSignal)
                }).on(next: {}, error: {error in}, completed: {}).start()
                self.streamContinuation = paginatedCollection.continuation
                self.updateLastUpdated(paginatedCollection.updated)
                    self.sink(.Next(.CompleteLoadingNext)) // First reload tableView,
                    if paginatedCollection.continuation == nil {    // then wait for next load
                        self.state = .Complete
                    } else {
                        self.state = .Normal
                    }
                },
                error: {error in
                    CloudAPIClient.handleError(error: error)
                    self.state = State.Error
                    self.sink(.Next(.FailToLoadNext))
                },
                completed: {
            })
            .start()
    }

    public func loadPlaylistOfEntry(entry: Entry) -> SignalProducer<Void, NSError> {
        if let url = entry.url {
            return musicfavClient.playlistify(url, errorOnFailure: false).map({ pl in
                var tracks = entry.enclosureTracks
                tracks.appendContentsOf(pl.getTracks())
                let playlist = Playlist(id: pl.id, title: pl.title, tracks: tracks)
                self.playlistsOfEntry[entry] = playlist
                UIScheduler().schedule {
                    self.sink(.Next(.CompleteLoadingPlaylist(playlist, entry)))
                }
                self.fetchTracks(playlist, entry: entry)
                return ()
            })
        }
        return SignalProducer<Void, NSError>.empty
    }

    public func fetchTracks(playlist: Playlist, entry: Entry) {
        loaderOfPlaylist[playlist]?.1.dispose()
        let loader = PlaylistLoader(playlist: playlist)
        let disposable = loader.fetchTracks().on(completed: {
            self.sink(.Next(.CompleteLoadingPlaylist(playlist, entry)))
        }).start()
        loaderOfPlaylist[playlist] = (loader, disposable)
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
            feedlyClient.markEntriesAsRead([entry.id]) { (req, res, result) in
                if result.isFailure { print("Failed to mark as read") }
                else                { print("Succeeded in marking as read") }
            }
        }
        entries.removeAtIndex(index)
        sink(.Next(.RemoveAt(index)))
    }

    public func markAsUnread(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { (req, res, result) in
                if result.isFailure { print("Failed to mark as unread") }
                else                { print("Succeeded in marking as unread") }
            })
        }
        entries.removeAtIndex(index)
        sink(.Next(.RemoveAt(index)))
    }

    public func markAsUnsaved(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.markEntriesAsUnsaved([entry.id]) { (req, res, result) in
                if result.isFailure { print("Failed to mark as unsaved") }
                else                { print("Succeeded in marking as unsaved") }
            }

            feedlyClient.markEntriesAsRead([entry.id]) { (req, res, result) in
                if result.isFailure { print("Failed to mark as read") }
                else                { print("Succeeded in marking as read") }
            }
        } else {
            EntryStore.remove(entry.toStoreObject())
        }
        entries.removeAtIndex(index)
        sink(.Next(.RemoveAt(index)))
    }
}
