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
    open static var sharedPipe: (Signal<Entry, NSError>, Signal<Entry, NSError>.Observer)! = Signal<Entry, NSError>.pipe()
    public typealias State = PaginatedCollectionRepositoryState
    public typealias Event = PaginatedCollectionRepositoryEvent
    public enum RemoveMark {
        case read
        case unread
        case unsave
    }

    open internal(set) var feedlyClient        = CloudAPIClient.shared
    open internal(set) var pinkspiderClient    = PinkSpiderAPIClient.shared

    open override func fetchCollection(streamId: String, paginationParams paginatedParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedEntryCollection, NSError> {
        return feedlyClient.fetchEntries(streamId: streamId, paginationParams: paginatedParams, useCache: useCache)
    }

    open override func dispose() {
        super.dispose()
        playlistifier?.dispose()
    }

    deinit {
        dispose()
    }

    open fileprivate(set) var playlistifiedEntriesOfEntry: [Entry:PlaylistifiedEntry]
    open fileprivate(set) var playlistQueue:               PlaylistQueue
    open var playlistifier:      Disposable?
    open var trackObserver:      Disposable?
    open var albumObserver:      Disposable?
    open var playlistObserver:   Disposable?

    public override init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int) {
        playlistifiedEntriesOfEntry = [:]
        playlistQueue               = PlaylistQueue(playlists: [])
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
        observe()
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

    public func observe() {
        trackObserver = TrackStreamRepository.sharedPipe.0.observe {
            guard let track = $0.value else { return }
            for entry in self.items {
                if let index = entry.tracks.index(of: track) {
                    var items = entry.tracks
                    items[index] = track
                    entry.tracks = items
                }
            }
        }
        albumObserver = AlbumStreamRepository.sharedPipe.0.observe {
            guard let album = $0.value else { return }
            for entry in self.items {
                if let index = entry.albums.index(of: album) {
                    var items = entry.albums
                    items[index] = album
                    entry.albums = items
                }
            }
        }
        playlistObserver = PlaylistStreamRepository.sharedPipe.0.observe {
            guard let playlist = $0.value else { return }
            for entry in self.items {
                if let index = entry.playlists.index(of: playlist) {
                    var items = entry.playlists
                    items[index] = playlist
                    entry.playlists = items
                }
            }
        }

    }

    open var playlists: [Playlist] {
        return items.map { $0.playlist }
                    .filter { $0 != nil && $0!.validTracksCount > 0 }
                    .map { $0! }
    }

    open override func itemsUpdated() {
        fetchAllPlaylists()
    }

    // MARK: - EntryRepository

    open func playlistify(_ entry: Entry) -> SignalProducer<(Track, Playlist), NSError> {
        guard let url = entry.url else { return SignalProducer<(Track, Playlist), NSError>.empty }

        if let playlist = entry.playlist {
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(playlist)
                                                                    .map { _, t in (t, playlist) })
        }
        if CloudAPIClient.includesTrack {
            let playlist = entry.toPlaylist()
            entry.playlist = playlist
            self.playlistQueue.enqueue(playlist)
            return SignalProducer<(Track, Playlist), NSError>.empty.concat(fetchTracks(playlist).map { _, t in (t, playlist) })
        }
        typealias S = SignalProducer<SignalProducer<(Track, Playlist), NSError>, NSError>
        let signal: S = pinkspiderClient.playlistify(url, errorOnFailure: false).map { en in
            var tracks = entry.audioTracks
            tracks.append(contentsOf: en.tracks)
            let playlist = Playlist(id: en.id, title: entry.title ?? en.title ?? "", tracks: tracks)
            entry.storedPlaylist = playlist
            self.playlistifiedEntriesOfEntry[entry] = en
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
        self.playlistifier = entries.map({ self.playlistify($0) })
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
            if stream == Tag.saved(userId) { return .unsave }
            if stream == Tag.read(userId)  { return .unread }
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

    open func markAs(_ action: MarkerAction, at index: Int) {
        let entry = items[index]
        feedlyClient.markEntriesAs(action, items: [entry]).flatMap(.concat) {
          self.feedlyClient.fetchEntry(entryId: entry.id)
        }.startWithResult { result in
            if let error = result.error {
                print("Failed to mark as \(action) \(error)")
            } else if let newEntry = result.value {
                print("Succeeded in marking as \(action)")
                self.items[index] = newEntry
                entry.updateExtentedProperties(newEntry)
                self.observer.send(value: .updatedAt(index))
                EntryRepository.sharedPipe.1.send(value: newEntry)
            }
        }
    }
    open func renew() -> EntryRepository {
        return EntryRepository(stream: stream, unreadOnly: unreadOnly, perPage: perPage) 
    }
}
