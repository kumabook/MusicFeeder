//
//  EntryRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/4/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit
import ReactiveSwift
import Result
import Realm

extension PaginatedEntryCollection: PaginatedCollection {}

open class EntryRepository: PaginatedCollectionRepository<PaginatedEntryCollection, Entry> {
    public typealias State = PaginatedCollectionRepositoryState
    public typealias Event = PaginatedCollectionRepositoryEvent
    public enum RemoveMark {
        case read
        case unread
        case unsave
    }

    open fileprivate(set) var feedlyClient        = CloudAPIClient.sharedInstance
    open fileprivate(set) var pinkspiderClient    = PinkSpiderAPIClient.sharedInstance

    open override func fetchCollection(streamId: String, paginationParams paginatedParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return feedlyClient.fetchEntries(streamId: streamId, paginationParams: paginatedParams)
    }

    open override func dispose() {
        super.dispose()
        playlistifier?.dispose()
    }

    deinit {
        dispose()
    }

    open fileprivate(set) var playlistsOfEntry:   [Entry:Playlist]
    open fileprivate(set) var playlistQueue:      PlaylistQueue
    open var playlistifier:      Disposable?

    public override init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
        playlistsOfEntry = [:]
        playlistQueue    = PlaylistQueue(playlists: [])
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    public convenience init(stream: FeedlyKit.Stream) {
        self.init(stream: stream, unreadOnly: false, perPage: CloudAPIClient.perPage)
    }

    public convenience init(stream: FeedlyKit.Stream, unreadOnly: Bool) {
        self.init(stream: stream, unreadOnly: unreadOnly, perPage: CloudAPIClient.perPage)
    }

    public convenience init(stream: FeedlyKit.Stream, perPage: Int) {
        self.init(stream: stream, unreadOnly: false, perPage: perPage)
    }

    open var playlists: [Playlist] {
        return items.map { self.playlistsOfEntry[$0] }
                    .filter { $0 != nil && $0!.validTracksCount > 0 }
                    .map { $0! }
    }

    // MARK: - PaginatedCollectionRepository protocol

    open override func addCacheItems(_ items: [Entry]) {
        let _ = EntryCacheList.findOrCreate(stream.streamId).add(items)
    }
    open override func loadCacheItems() {
        cacheItems = realize(EntryCacheList.findOrCreate(stream.streamId).items).map { Entry(store: $0 as! EntryStore) }
    }
    open override func clearCacheItems() {
        let _ = EntryCacheList.findOrCreate(stream.streamId).clear()
    }
    open override func itemsUpdated() {
        fetchAllPlaylists()
    }

    // MARK: - EntryRepository

    open func loadPlaylistOfEntry(_ entry: Entry) -> SignalProducer<(Track, Playlist), NSError> {
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
            tracks.append(contentsOf: pl.getTracks())
            let playlist = Playlist(id: pl.id, title: entry.title!, tracks: tracks)
            self.playlistsOfEntry[entry] = playlist
            self.playlistQueue.enqueue(playlist)
            UIScheduler().schedule { self.observer.send(value: .completeLoadingPlaylist(playlist, entry)) }
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(self.fetchTracks(playlist)
                                                                     .map { _, t in (t, playlist) })
        }
        return signal.flatten(.merge)
    }

    internal func fetchTracks(_ playlist: Playlist) -> SignalProducer<(Int, Track), NSError> {
        return PlaylistRepository(playlist: playlist).fetchTracks()
    }

    open func fetchAllPlaylists() {
        cancelFetchingPlaylists()
        fetchPlaylistsOfEntries(items)
    }

    open func fetchPlaylistsOfEntries(_ entries: [Entry]) {
        self.playlistifier?.dispose()
        self.playlistifier = entries.map({ self.loadPlaylistOfEntry($0) })
                                    .reduce(SignalProducer<(Track, Playlist), NSError>.empty, { $0.concat($1) })
                                    .on(value: { track, playlist in
                                        self.playlistQueue.trackUpdated(track)
                                    }).start()
    }

    open func cancelFetchingPlaylists() {
        playlistifier?.dispose()
    }

    open var removeMark: RemoveMark {
        if let userId = CloudAPIClient._profile?.id {
            if stream == Tag.Saved(userId) { return .unsave }
            if stream == Tag.Read(userId)  { return .unread }
        }
        return .read
    }

    open func markAsRead(_ index: Int) {
        let entry = items[index]
        if CloudAPIClient.isLoggedIn {
            let _ = feedlyClient.markEntriesAsRead([entry.id]) { response in
                if let error = response.error { print("Failed to mark as read \(error)") }
                else                          { print("Succeeded in marking as read") }
            }
        }
        items.remove(at: index)
        observer.send(value: .removeAt(index))
    }

    open func markAsUnread(_ index: Int) {
        let entry = items[index]
        if CloudAPIClient.isLoggedIn {
            let _ = feedlyClient.keepEntriesAsUnread([entry.id], completionHandler: { response in
                if let error = response.error { print("Failed to mark as unread \(error)") }
                else                          { print("Succeeded in marking as unread") }
            })
        }
        let _ = items.remove(at: index)
        observer.send(value: .removeAt(index))
    }

    open func markAsUnsaved(_ index: Int) {
        let entry = items[index]
        if CloudAPIClient.isLoggedIn {
            let _ = feedlyClient.markEntriesAsUnsaved([entry.id]) { response in
                if let error = response.error { print("Failed to mark as unsaved \(error)") }
                else                          { print("Succeeded in marking as unsaved") }
            }

            let _ = feedlyClient.markEntriesAsRead([entry.id]) { response in
                if let error = response.error { print("Failed to mark as read \(error)") }
                else                { print("Succeeded in marking as read") }
            }
        } else {
            EntryStore.remove(entry.toStoreObject())
        }
        items.remove(at: index)
        observer.send(value: .removeAt(index))
    }
}
