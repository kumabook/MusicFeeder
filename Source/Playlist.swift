//
//  Playlist.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveSwift
import Result
import PlayerKit
import Breit

public enum PlaylistEvent {
    case load(index: Int)
    case changePlayState(index: Int, playerState: PlayerState)
}

open class Playlist: PlayerKit.Playlist, Equatable, Hashable {
    open fileprivate(set) var id: String
    open var title:        String
    fileprivate var _tracks:     [Track]
    open var createdAt:    Int64
    open var updatedAt:    Int64
    open var number:       Float
    open var thumbnailUrl: URL? { return _tracks.first?.thumbnailUrl }
    open var signal:       Signal<PlaylistEvent, NSError>
    open var observer:     Signal<PlaylistEvent, NSError>.Observer

    open var tracks: [PlayerKit.Track] { return _tracks.map { $0 as PlayerKit.Track }}
    open var validTracksCount: Int {
        return tracks.filter({ $0.streamUrl != nil}).count
    }

    open func getTracks() -> [Track] { return _tracks }
    
    open static var playlistNumberLimit: Int = 5
    open static var trackNumberLimit:    Int = 5

    open static var sharedOrderBy = OrderBy.number(OrderType.desc)
    open static var sharedPipe: (Signal<Event, NSError>, Signal<Event, NSError>.Observer)! = Signal<Event, NSError>.pipe()
    open static var sharedList: [Playlist] = Playlist.findAll(sharedOrderBy)
    open static func updatePlaylistInSharedList(_ playlists: [Playlist]) -> PersistentResult {
        for playlist in  playlists {
            let _ = playlist.save(true)
        }
        notifyChange(.sharedListUpdated)
        return .success
    }
    
    public enum Event {
        case created(Playlist)
        case removed(Playlist)
        case updated(Playlist)
        case tracksAdded( Playlist, [Track])
        case trackRemoved(Playlist, Track, Int)
        case trackUpdated(Playlist, Track)
        case sharedListUpdated
    }

    open class var shared: (signal: Signal<Event, NSError>, observer: Signal<Event, NSError>.Observer, current: [Playlist]) {
        get { return (signal: Playlist.sharedPipe.0,
                    observer: Playlist.sharedPipe.1,
                     current: Playlist.sharedList) }
    }

    open class func notifyChange(_ event: Event) {
        switch event {
        case .created:
            Playlist.sharedList = Playlist.findAll(sharedOrderBy)
        case .removed(let playlist):
            if let index = Playlist.sharedList.index(of: playlist) {
                Playlist.sharedList.remove(at: index)
            }
        case .updated(let playlist):
            if let index = Playlist.sharedList.index(of: playlist) {
                Playlist.sharedList[index] = playlist
            }
        case .tracksAdded(_, _):
            break
        case .trackRemoved(_, _, _):
            break
        case .trackUpdated(_, _):
            break
        case .sharedListUpdated:
            Playlist.sharedList = Playlist.findAll(sharedOrderBy)
        }
        shared.observer.send(value: event)
    }

    fileprivate class func dateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter
    }

    public init(title: String) {
        self.id       = "\(title)-created-\(Playlist.dateFormatter().string(from: NSDate() as Date))"
        self.title     = title
        self._tracks   = []
        let pipe       = Signal<PlaylistEvent, NSError>.pipe()
        self.signal    = pipe.0
        self.observer  = pipe.1
        self.createdAt = Date().timestamp
        self.updatedAt = Date().timestamp
        self.number    = 0
    }

    public init(id: String, title: String, tracks: [Track]) {
        self.id      = id
        self.title    = title
        self._tracks  = tracks
        let pipe      = Signal<PlaylistEvent, NSError>.pipe()
        self.signal   = pipe.0
        self.observer = pipe.1
        self.createdAt = Date().timestamp
        self.updatedAt = Date().timestamp
        self.number    = Float(PlaylistStore.findAll().count)
    }

    public init(json: JSON) {
        id           = json["url"].stringValue
        title         = json["title"].stringValue
        _tracks       = json["tracks"].arrayValue.map({ Track(json: $0) })
        createdAt     = Date().timestamp
        updatedAt     = Date().timestamp
        number        = json["number"].floatValue
        let pipe      = Signal<PlaylistEvent, NSError>.pipe()
        self.signal   = pipe.0
        self.observer = pipe.1
    }

    public init(store: PlaylistStore) {
        id       = store.id
        title     = store.title
        _tracks   = [] as [Track]
        createdAt = store.createdAt
        updatedAt = store.updatedAt
        number    = store.number
        for trackStore in realize(store.tracks) {
            _tracks.append(Track(store:trackStore as! TrackStore))
        }
        let pipe      = Signal<PlaylistEvent, NSError>.pipe()
        self.signal   = pipe.0
        self.observer = pipe.1
    }

    open var hashValue: Int {
        return id.hashValue
    }

    internal func toStoreObject() -> PlaylistStore {
        let store       = PlaylistStore()
        store.id        = id
        store.title     = title
        store.createdAt = createdAt
        store.updatedAt = updatedAt
        store.number    = number
        store.tracks.addObjects(_tracks.map({ $0.toStoreObject() }) as NSArray)
        return store
    }

    open func create() -> PersistentResult {
        let result = PlaylistStore.create(self)
        if result == .success {
            Playlist.notifyChange(.created(self))
        }
        return result
    }

    open class func movePlaylistInSharedList(_ sourceIndex: Int, toIndex: Int) -> PersistentResult {
        let source     = sharedList[sourceIndex]
        let destNumber = sharedList[toIndex].number
        var nextIndex  = toIndex
        var direction  = 0 as Float
        if toIndex > sourceIndex {
            nextIndex = toIndex + 1
            direction = sharedOrderBy.ascending ? 1 : -1
        } else if toIndex < sourceIndex {
            nextIndex = toIndex - 1
            direction = sharedOrderBy.ascending ? -1 : 1
        }
        if let next = sharedList.get(nextIndex) {
            source.number = (destNumber + next.number) / 2
        } else {
            source.number = destNumber + direction
        }
        return Playlist.updatePlaylistInSharedList([source])
    }

    open func save(_ slient: Bool = false) -> Bool {
        if PlaylistStore.save(self) {
            if !slient {
                Playlist.notifyChange(.updated(self))
            }
            return true
        } else {
            return false
        }
    }

    open func remove() {
        PlaylistStore.remove(self)
        Playlist.notifyChange(.removed(self))
    }

    open func removeTrackAtIndex(_ index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
        let track = _tracks.remove(at: Int(index))
        Playlist.notifyChange(.trackRemoved(self, track, Int(index)))
    }

    open func insertTrack(_ track: Track, atIndex: UInt) -> PersistentResult {
        let trackStore = TrackStore.findBy(url: track.url) ?? track.toStoreObject()
        guard let store = PlaylistStore.findBy(id: id) else { return .failure }
        let result = store.insertTrack(trackStore, atIndex: atIndex)
        if result == .success {
            Playlist.notifyChange(.tracksAdded(self, [track]))
        }
        return result
    }

    open func appendTracks(_ tracks: [Track]) -> PersistentResult {
        let result = PlaylistStore.appendTracks(tracks, playlist: self)
        if result == .success {
            self._tracks.append(contentsOf: tracks)
            Playlist.notifyChange(.tracksAdded(self, tracks))
        }
        return result
    }

    open func moveTrackAtIndex(_ sourceIndex: Int, toIndex: Int) -> PersistentResult {
        guard let store = PlaylistStore.findBy(id: id) else { return .failure }
        let result = store.moveTrackAtIndex(UInt(sourceIndex), toIndex: UInt(toIndex))
        switch result {
        case .success:
            let t = _tracks[sourceIndex]
            _tracks[sourceIndex] = _tracks[toIndex]
            _tracks[toIndex]     = t
        default: break
        }
        return result
    }

    open class func findAll(_ orderBy: OrderBy = .number(.desc)) -> [Playlist] {
        var playlists: [Playlist] = []
        for store in realizeResults(PlaylistStore.findAll(orderBy)) {
            playlists.append(Playlist(store: store as! PlaylistStore))
        }
        return playlists
    }

    open class func findBy(id: String) -> Playlist? {
        if let store = PlaylistStore.findBy(id: id) {
            return Playlist(store: store)
        } else {
            return nil
        }
    }

    open class func removeAll() {
        PlaylistStore.removeAll()
    }

    open class func createDefaultPlaylist() {
        if Playlist.sharedList.count == 0 {
            let _ = Playlist(title: "Favorite").create()
        }
    }

    open func reloadExpiredTracks() -> SignalProducer<Playlist, NSError> {
        var signal = SignalProducer<Track, NSError>.empty
        for track in getTracks() {
            signal = signal.concat(track.fetchPropertiesFromProviderIfNeed())
        }
        return signal.map { _ in self }
    }
}

public func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.id == rhs.id
}
