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
    public var loaderOfPlaylist:   [Playlist: PlaylistLoader]
    public var playlistifier:      Disposable?
    public var streamContinuation: String?
    public var signal:             Signal<Event, NSError>
    public var observer:           Signal<Event, NSError>.Observer
    private var _unreadOnly:       Bool
    private var _perPage:          Int
    private var _needsPlaylist:    Bool

    public init(stream: Stream) {
        self.stream      = stream
        state            = .Normal
        lastUpdated      = 0
        entries          = []
        playlistsOfEntry = [:]
        loaderOfPlaylist = [:]
        let pipe         = Signal<Event, NSError>.pipe()
        signal           = pipe.0
        observer         = pipe.1
        _unreadOnly      = false
        _perPage         = CloudAPIClient.perPage
        _needsPlaylist   = true
    }

    public convenience init(stream: Stream, unreadOnly: Bool) {
        self.init(stream: stream)
        _unreadOnly = unreadOnly
    }

    public convenience init(stream: Stream, perPage: Int, needsPlaylist: Bool) {
        self.init(stream: stream)
        _perPage       = perPage
        _needsPlaylist = needsPlaylist
    }

    public convenience init(stream: Stream, unreadOnly: Bool, perPage: Int, needsPlaylist: Bool) {
        self.init(stream: stream)
        _unreadOnly    = unreadOnly
        _perPage       = perPage
        _needsPlaylist = needsPlaylist
    }

    deinit {
        dispose()
    }

    public func dispose() {
        for loader in loaderOfPlaylist {
            loader.1.dispose()
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
                                           unreadOnly: unreadOnly,
                                              perPage: _perPage)
        observer.sendNext(.StartLoadingLatest)
        producer
            .startOn(UIScheduler())
            .on(
                next: { paginatedCollection in
                    var latestEntries = paginatedCollection.items
                    latestEntries.appendContentsOf(self.entries)
                    self.entries = latestEntries
                    self.updateLastUpdated(paginatedCollection.updated)
                    if self._needsPlaylist {
                        self.fetchAllPlaylists()
                    }
                },
                failed: { error in CloudAPIClient.handleError(error: error) },
                completed: {
                    self.observer.sendNext(.CompleteLoadingLatest)
            }).start()
    }

    public func fetchEntries() {
        if state != .Normal && state != .Error {
            return
        }
        state = .Fetching
        observer.sendNext(.StartLoadingNext)
        var producer: SignalProducer<PaginatedEntryCollection, NSError>
        producer = feedlyClient.fetchEntries(streamId:stream.streamId,
                                         continuation: streamContinuation,
                                           unreadOnly: unreadOnly,
                                              perPage: _perPage)
        producer
            .startOn(UIScheduler())
            .on(next: { paginatedCollection in
                let entries = paginatedCollection.items
                self.entries.appendContentsOf(entries)
                self.streamContinuation = paginatedCollection.continuation
                self.updateLastUpdated(paginatedCollection.updated)
                if self._needsPlaylist {
                    self.fetchAllPlaylists()
                }
                self.observer.sendNext(.CompleteLoadingNext) // First reload tableView,
                if paginatedCollection.continuation == nil {    // then wait for next load
                    self.state = .Complete
                } else {
                    self.state = .Normal
                }
                },
                failed: {error in
                    CloudAPIClient.handleError(error: error)
                    self.observer.sendNext(.FailToLoadNext)
                    self.state = State.Error
                },
                completed: {
            })
            .start()
    }

    // This method needs to be fixed, but currently ReactiveCocoa has problem about cancelling inner signal
    // So, we check if playlistifier is disposed before proceed the next signal
    public func loadPlaylistOfEntry(entry: Entry) -> SignalProducer<Void, NSError> {
        if let url = entry.url {
            if let playlist = self.playlistsOfEntry[entry] {
                fetchTracks(playlist, entry: entry)
                return SignalProducer<Void, NSError>(value: ())
            } else if CloudAPIClient.includesTrack {
                self.playlistsOfEntry[entry] = entry.playlist
                return SignalProducer<Void, NSError>(value: ())
            } else {
                let signal: SignalProducer<SignalProducer<Void, NSError>, NSError> = musicfavClient.playlistify(url, errorOnFailure: false).map({ pl in
                    var tracks = entry.audioTracks
                    tracks.appendContentsOf(pl.getTracks())
                    let playlist = Playlist(id: pl.id, title: entry.title!, tracks: tracks)
                    self.playlistsOfEntry[entry] = playlist
                    UIScheduler().schedule {
                        self.observer.sendNext(.CompleteLoadingPlaylist(playlist, entry))
                    }
                    // Check if it is disposed
                    if let disposed = self.playlistifier?.disposed where !disposed {
                        self.fetchTracks(playlist, entry: entry)
                    }
                    return SignalProducer<Void, NSError>.empty
                })
                return signal.flatten(.Merge)
            }
        }
        return SignalProducer<Void, NSError>.empty
    }

    internal func fetchTracks(playlist: Playlist, entry: Entry) {
        let loader = PlaylistLoader(playlist: playlist)
        loaderOfPlaylist[playlist]?.dispose()
        loaderOfPlaylist[playlist] = loader
        loader.fetchTracks()
    }

    public func fetchAllPlaylists() {
        cancelFetchingPlaylists()
        fetchPlaylistsOfEntries(entries)
    }

    public func fetchPlaylistsOfEntries(_entries: [Entry]) {
        self.playlistifier?.dispose()
        self.playlistifier = _entries.map({
            self.loadPlaylistOfEntry($0)
        }).reduce(SignalProducer<Void, NSError>.empty, combine: { (currentSignal, nextSignal) in
            currentSignal.concat(nextSignal)
        }).on().start()
    }

    public func cancelFetchingPlaylists() {
        playlistifier?.dispose()
        loaderOfPlaylist.forEach {
            $1.dispose()
            self.loaderOfPlaylist[$0] = nil
        }
    }

    public var unreadOnly: Bool {
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { return false }
            if stream == Tag.Read(userId) {  return false }
        }
        return _unreadOnly
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
            feedlyClient.markEntriesAsRead([entry.id]) { response in
                if response.result.isFailure { print("Failed to mark as read") }
                else                { print("Succeeded in marking as read") }
            }
        }
        entries.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }

    public func markAsUnread(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { response in
                if response.result.isFailure { print("Failed to mark as unread") }
                else                { print("Succeeded in marking as unread") }
            })
        }
        entries.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }

    public func markAsUnsaved(index: Int) {
        let entry = entries[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.markEntriesAsUnsaved([entry.id]) { response in
                if response.result.isFailure { print("Failed to mark as unsaved") }
                else                { print("Succeeded in marking as unsaved") }
            }

            feedlyClient.markEntriesAsRead([entry.id]) { response in
                if response.result.isFailure { print("Failed to mark as read") }
                else                { print("Succeeded in marking as read") }
            }
        } else {
            EntryStore.remove(entry.toStoreObject())
        }
        entries.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }
}
