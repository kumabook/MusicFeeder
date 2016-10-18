//
//  Playlist.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveCocoa
import Result
import PlayerKit

public enum PlaylistEvent {
    case Load(index: Int)
    case ChangePlayState(index: Int, playerState: PlayerState)
}

public class Playlist: PlayerKit.Playlist, Equatable, Hashable {
    public private(set) var id: String
    public var title:        String
    private var _tracks:     [Track]
    public var createdAt:    Int64
    public var updatedAt:    Int64
    public var number:       Float
    public var thumbnailUrl: NSURL? { return _tracks.first?.thumbnailUrl }
    public var signal:       Signal<PlaylistEvent, NSError>
    public var observer:     Signal<PlaylistEvent, NSError>.Observer

    public var tracks: [PlayerKit.Track] { return _tracks.map { $0 as PlayerKit.Track }}
    public var validTracksCount: Int {
        return tracks.filter({ $0.streamUrl != nil}).count
    }

    public func getTracks() -> [Track] { return _tracks }
    
    public static var playlistNumberLimit: Int = 5
    public static var trackNumberLimit:    Int = 5

    public static var sharedOrderBy = OrderBy.Number(OrderType.Desc)
    public static var sharedPipe: (Signal<Event, NSError>, Signal<Event, NSError>.Observer)! = Signal<Event, NSError>.pipe()
    public static var sharedList: [Playlist] = Playlist.findAll(sharedOrderBy)
    public static func updatePlaylistInSharedList(playlists: [Playlist]) -> PersistentResult {
        for playlist in  playlists {
            playlist.save(true)
        }
        notifyChange(.SharedListUpdated)
        return .Success
    }
    
    public enum Event {
        case Created(Playlist)
        case Removed(Playlist)
        case Updated(Playlist)
        case TracksAdded( Playlist, [Track])
        case TrackRemoved(Playlist, Track, Int)
        case TrackUpdated(Playlist, Track)
        case SharedListUpdated
    }

    public class var shared: (signal: Signal<Event, NSError>, observer: Signal<Event, NSError>.Observer, current: [Playlist]) {
        get { return (signal: Playlist.sharedPipe.0,
                    observer: Playlist.sharedPipe.1,
                     current: Playlist.sharedList) }
    }

    public class func notifyChange(event: Event) {
        switch event {
        case .Created:
            Playlist.sharedList = Playlist.findAll(sharedOrderBy)
        case .Removed(let playlist):
            if let index = Playlist.sharedList.indexOf(playlist) {
                Playlist.sharedList.removeAtIndex(index)
            }
        case .Updated(let playlist):
            if let index = Playlist.sharedList.indexOf(playlist) {
                Playlist.sharedList[index] = playlist
            }
        case .TracksAdded(_, _):
            break
        case .TrackRemoved(_, _, _):
            break
        case .TrackUpdated(_, _):
            break
        case .SharedListUpdated:
            Playlist.sharedList = Playlist.findAll(sharedOrderBy)
        }
        shared.observer.sendNext(event)
    }

    private class func dateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter
    }

    public init(title: String) {
        self.id       = "\(title)-created-\(Playlist.dateFormatter().stringFromDate(NSDate()))"
        self.title     = title
        self._tracks   = []
        let pipe       = Signal<PlaylistEvent, NSError>.pipe()
        self.signal    = pipe.0
        self.observer  = pipe.1
        self.createdAt = NSDate().timestamp
        self.updatedAt = NSDate().timestamp
        self.number    = 0
    }

    public init(id: String, title: String, tracks: [Track]) {
        self.id      = id
        self.title    = title
        self._tracks  = tracks
        let pipe      = Signal<PlaylistEvent, NSError>.pipe()
        self.signal   = pipe.0
        self.observer = pipe.1
        self.createdAt = NSDate().timestamp
        self.updatedAt = NSDate().timestamp
        self.number    = Float(PlaylistStore.findAll().count)
    }

    public init(json: JSON) {
        id           = json["url"].stringValue
        title         = json["title"].stringValue
        _tracks       = json["tracks"].arrayValue.map({ Track(json: $0) })
        createdAt     = NSDate().timestamp
        updatedAt     = NSDate().timestamp
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
        for trackStore in store.tracks {
            _tracks.append(Track(store:trackStore as! TrackStore))
        }
        let pipe      = Signal<PlaylistEvent, NSError>.pipe()
        self.signal   = pipe.0
        self.observer = pipe.1
    }

    public var hashValue: Int {
        return id.hashValue
    }

    internal func toStoreObject() -> PlaylistStore {
        let store       = PlaylistStore()
        store.id        = id
        store.title     = title
        store.createdAt = createdAt
        store.updatedAt = updatedAt
        store.number    = number
        store.tracks.addObjects(_tracks.map({ $0.toStoreObject() }))
        return store
    }

    public func create() -> PersistentResult {
        let result = PlaylistStore.create(self)
        if result == .Success {
            Playlist.notifyChange(.Created(self))
        }
        return result
    }

    public class func movePlaylistInSharedList(sourceIndex: Int, toIndex: Int) -> PersistentResult {
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

    public func save(slient: Bool = false) -> Bool {
        if PlaylistStore.save(self) {
            if !slient {
                Playlist.notifyChange(.Updated(self))
            }
            return true
        } else {
            return false
        }
    }

    public func remove() {
        PlaylistStore.remove(self)
        Playlist.notifyChange(.Removed(self))
    }

    public func removeTrackAtIndex(index: UInt) {
        PlaylistStore.removeTrackAtIndex(index, playlist: self)
        let track = _tracks.removeAtIndex(Int(index))
        Playlist.notifyChange(.TrackRemoved(self, track, Int(index)))
    }

    public func insertTrack(track: Track, atIndex: UInt) -> PersistentResult {
        let trackStore = TrackStore.findBy(url: track.url) ?? track.toStoreObject()
        guard let store = PlaylistStore.findBy(id: id) else { return .Failure }
        let result = store.insertTrack(trackStore, atIndex: atIndex)
        if result == .Success {
            Playlist.notifyChange(.TracksAdded(self, [track]))
        }
        return result
    }

    public func appendTracks(tracks: [Track]) -> PersistentResult {
        let result = PlaylistStore.appendTracks(tracks, playlist: self)
        if result == .Success {
            self._tracks.appendContentsOf(tracks)
            Playlist.notifyChange(.TracksAdded(self, tracks))
        }
        return result
    }

    public func moveTrackAtIndex(sourceIndex: Int, toIndex: Int) -> PersistentResult {
        guard let store = PlaylistStore.findBy(id: id) else { return .Failure }
        let result = store.moveTrackAtIndex(UInt(sourceIndex), toIndex: UInt(toIndex))
        switch result {
        case .Success:
            let t = _tracks[sourceIndex]
            _tracks[sourceIndex] = _tracks[toIndex]
            _tracks[toIndex]     = t
        default: break
        }
        return result
    }

    public class func findAll(orderBy: OrderBy = .Number(.Desc)) -> [Playlist] {
        var playlists: [Playlist] = []
        for store in PlaylistStore.findAll(orderBy) {
            playlists.append(Playlist(store: store as! PlaylistStore))
        }
        return playlists
    }

    public class func findBy(id id: String) -> Playlist? {
        if let store = PlaylistStore.findBy(id: id) {
            return Playlist(store: store)
        } else {
            return nil
        }
    }

    public class func removeAll() {
        PlaylistStore.removeAll()
    }

    public class func createDefaultPlaylist() {
        if Playlist.sharedList.count == 0 {
            Playlist(title: "Favorite").create()
        }
    }

    public func reloadExpiredTracks() -> SignalProducer<Playlist, NSError> {
        var signal = SignalProducer<Track, NSError>.empty
        for track in getTracks() {
            signal = signal.concat(track.reloadExpiredDetail())
        }
        return signal.map { _ in self }
    }
}

public func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.id == rhs.id
}
