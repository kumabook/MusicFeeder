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
    public private(set) var musicfavClient      = MusicFavAPIClient.sharedInstance


    public override func fetchCollection(streamId streamId: String, paginationParams paginatedParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return feedlyClient.fetchEntries(streamId: streamId,
                                     continuation: paginatedParams.continuation,
                                       unreadOnly: paginatedParams.unreadOnly ?? false,
                                          perPage: paginatedParams.count ?? CloudAPIClient.perPage)
    }

    public override func dispose() {
        super.dispose()
        for loader in loaderOfPlaylist {
            loader.1.dispose()
        }
        playlistifier?.dispose()
    }

    deinit {
        dispose()
    }

    public private(set) var needsPlaylist:      Bool
    public private(set) var playlistsOfEntry:   [Entry:Playlist]
    public var loaderOfPlaylist:   [Playlist: PlaylistLoader]
    public var playlistifier:      Disposable?

    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        needsPlaylist    = true
        playlistsOfEntry = [:]
        loaderOfPlaylist = [:]
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
        fetchPlaylistsOfEntries(items)
    }

    public func fetchPlaylistsOfEntries(entries: [Entry]) {
        self.playlistifier?.dispose()
        self.playlistifier = entries.map({
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
