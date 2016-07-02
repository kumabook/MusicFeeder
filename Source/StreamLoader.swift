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

extension PaginatedEntryCollection: PaginatedCollection {}

public class StreamLoader: PaginatedCollectionLoader<PaginatedEntryCollection, Entry> {
    public typealias State = PaginatedCollectionLoaderState
    public typealias Event = PaginatedCollectionLoaderEvent
    public enum RemoveMark {
        case Read
        case Unread
        case Unsave
    }

    public private(set) var feedlyClient        = CloudAPIClient.sharedInstance
    public private(set) var pinkspiderClient    = PinkSpiderAPIClient.sharedInstance


    public override func fetchCollection(streamId streamId: String, paginationParams paginatedParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return feedlyClient.fetchEntries(streamId: streamId, paginationParams: paginatedParams)
    }

    public override func dispose() {
        super.dispose()
        playlistifier?.dispose()
    }

    deinit {
        dispose()
    }

    public private(set) var needsPlaylist:      Bool
    public private(set) var playlistsOfEntry:   [Entry:Playlist]
    public private(set) var playlistQueue:      PlaylistQueue
    public var playlistifier:      Disposable?

    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        needsPlaylist    = true
        playlistsOfEntry = [:]
        playlistQueue    = PlaylistQueue(playlists: [])
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    public convenience init(stream: Stream) {
        self.init(stream: stream, unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    public convenience init(stream: Stream, unreadOnly: Bool) {
        self.init(stream: stream, unreadOnly: unreadOnly, perPage: CloudAPIClient.perPage)
    }

    public convenience init(stream: Stream, perPage: Int, needsPlaylist: Bool) {
        self.init(stream: stream, unreadOnly: false, perPage: perPage)
        self.needsPlaylist = needsPlaylist
    }

    public convenience init(stream: Stream, unreadOnly: Bool, perPage: Int, needsPlaylist: Bool) {
        self.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
        self.needsPlaylist = needsPlaylist
    }

    public var playlists: [Playlist] {
        return items.map { self.playlistsOfEntry[$0] }
                    .filter { $0 != nil && $0!.validTracksCount > 0 }
                    .map { $0! }
    }

    public func fetchEntries()       { fetchItems() }
    public func fetchLatestEntries() { fetchLatestItems() }

    public var entries: [Entry]             { return self.items }

    public override func itemsUpdated() {
        fetchAllPlaylists()
    }

    public func loadPlaylistOfEntry(entry: Entry) -> SignalProducer<(Track, Playlist), NSError> {
        guard let url = entry.url else { return SignalProducer<(Track, Playlist), NSError>.empty }

        if let playlist = self.playlistsOfEntry[entry] {
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(playlist)
                                                                    .map { _, t in (t, playlist) })
        }
        if CloudAPIClient.includesTrack {
            let playlist = entry.toPlaylist()
            self.playlistsOfEntry[entry] = playlist
            self.playlistQueue.enqueue(playlist)
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(playlist)
                                                                           .map { _, t in (t, playlist) })
        }
        typealias S = SignalProducer<SignalProducer<(Track, Playlist), NSError>, NSError>
        let signal: S = pinkspiderClient.playlistify(url, errorOnFailure: false).map { pl in
            var tracks = entry.audioTracks
            tracks.appendContentsOf(pl.getTracks())
            let playlist = Playlist(id: pl.id, title: entry.title!, tracks: tracks)
            self.playlistsOfEntry[entry] = playlist
            self.playlistQueue.enqueue(playlist)
            UIScheduler().schedule { self.observer.sendNext(.CompleteLoadingPlaylist(playlist, entry)) }
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(self.fetchTracks(playlist)
                                                                     .map { _, t in (t, playlist) })
        }
        return signal.flatten(.Merge)
    }

    internal func fetchTracks(playlist: Playlist) -> SignalProducer<(Int, Track), NSError> {
        return PlaylistLoader(playlist: playlist).fetchTracks()
    }

    public func fetchAllPlaylists() {
        cancelFetchingPlaylists()
        fetchPlaylistsOfEntries(items)
    }

    public func fetchPlaylistsOfEntries(entries: [Entry]) {
        self.playlistifier?.dispose()
        self.playlistifier = entries.map({ self.loadPlaylistOfEntry($0) })
                                    .reduce(SignalProducer<(Track, Playlist), NSError>.empty, combine: { $0.concat($1) })
                                    .on(next: { track, playlist in
                                        self.playlistQueue.trackUpdated(track)
                                    }).start()
    }

    public func cancelFetchingPlaylists() {
        playlistifier?.dispose()
    }

    public var removeMark: RemoveMark {
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { return .Unsave }
            if stream == Tag.Read(userId)  { return .Unread }
        }
        return .Read
    }

    public func markAsRead(index: Int) {
        let entry = items[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.markEntriesAsRead([entry.id]) { response in
                if response.result.isFailure { print("Failed to mark as read") }
                else                { print("Succeeded in marking as read") }
            }
        }
        items.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }

    public func markAsUnread(index: Int) {
        let entry = items[index]
        if CloudAPIClient.isLoggedIn {
            feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { response in
                if response.result.isFailure { print("Failed to mark as unread") }
                else                { print("Succeeded in marking as unread") }
            })
        }
        items.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }

    public func markAsUnsaved(index: Int) {
        let entry = items[index]
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
        items.removeAtIndex(index)
        observer.sendNext(.RemoveAt(index))
    }
}
