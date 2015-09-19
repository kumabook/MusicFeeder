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
    public let _id:          String
    public var title:        String
    private var _tracks:     [Track]
    public
    var thumbnailUrl: NSURL? { return _tracks.first?.thumbnailUrl }
    public var signal:       Signal<PlaylistEvent, NSError>
    public var sink:         Signal<PlaylistEvent, NSError>.Observer

    public var id:     String { return _id }
    public var tracks: [PlayerKit.Track] { return _tracks }
    public var validTracksCount: Int {
        return tracks.filter({ $0.streamUrl != nil}).count
    }

    public func getTracks() -> [Track] { return _tracks }
    
    public static var playlistNumberLimit: Int = 5
    public static var trackNumberLimit:    Int = 5

    public static var sharedPipe: (Signal<Event, NSError>, Signal<Event, NSError>.Observer)! = Signal<Event, NSError>.pipe()
    public static var sharedList: [Playlist] = Playlist.findAll()
    
    public enum Event {
        case Created(Playlist)
        case Removed(Playlist)
        case Updated(Playlist)
        case TracksAdded( Playlist, [Track])
        case TrackRemoved(Playlist, Track, Int)
        case TrackUpdated(Playlist, Track)
    }

    public class var shared: (signal: Signal<Event, NSError>, sink: ReactiveCocoa.Event<Event, NSError> -> (), current: [Playlist]) {
        get { return (signal: Playlist.sharedPipe.0,
                        sink: Playlist.sharedPipe.1,
                     current: Playlist.sharedList) }
    }

    public class func notifyChange(event: Event) {
        switch event {
        case .Created(let playlist):
            Playlist.sharedList.append(playlist)
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
        }
        shared.sink(ReactiveCocoa.Event<Event, NSError>.Next(event))
    }

    private class func dateFormatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        return dateFormatter
    }

    public init(title: String) {
        self._id     = "\(title)-created-\(Playlist.dateFormatter().stringFromDate(NSDate()))"
        self.title   = title
        self._tracks = []
        let pipe     = Signal<PlaylistEvent, NSError>.pipe()
        self.signal  = pipe.0
        self.sink    = pipe.1
    }

    public init(id: String, title: String, tracks: [Track]) {
        self._id     = id
        self.title   = title
        self._tracks = tracks
        let pipe     = Signal<PlaylistEvent, NSError>.pipe()
        self.signal  = pipe.0
        self.sink    = pipe.1
    }

    public init(json: JSON) {
        _id         = json["url"].stringValue
        title       = json["title"].stringValue
        _tracks     = json["tracks"].arrayValue.map({ Track(json: $0) })
        let pipe    = Signal<PlaylistEvent, NSError>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    public init(store: PlaylistStore) {
        _id     = store.id
        title   = store.title
        _tracks = [] as [Track]
        for trackStore in store.tracks {
            _tracks.append(Track(store:trackStore as! TrackStore))
        }
        let pipe    = Signal<PlaylistEvent, NSError>.pipe()
        self.signal = pipe.0
        self.sink   = pipe.1
    }

    public var hashValue: Int {
        return id.hashValue
    }

    internal func toStoreObject() -> PlaylistStore {
        let store    = PlaylistStore()
        store.id     = id
        store.title  = title
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

    public func save() -> Bool {
        if PlaylistStore.save(self) {
            Playlist.notifyChange(.Updated(self))
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

    public func appendTracks(tracks: [Track]) -> PersistentResult {
        let result = PlaylistStore.appendTracks(tracks, playlist: self)
        if result == .Success {
            self._tracks.appendContentsOf(tracks)
            Playlist.notifyChange(.TracksAdded(self, tracks))
        }
        return result
    }

    public class func findAll() -> [Playlist] {
        return PlaylistStore.findAll()
    }

    public class func removeAll() {
        PlaylistStore.removeAll()
    }

    public class func createDefaultPlaylist() {
        if Playlist.sharedList.count == 0 {
            Playlist(title: "Favorite").create()
        }
    }
}

public func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.id == rhs.id
}
