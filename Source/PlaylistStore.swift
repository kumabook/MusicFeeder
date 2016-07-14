//
//  PlaylistStore.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Realm

import FeedlyKit

extension RLMArray: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}
extension RLMResults: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

public enum PersistentResult {
    case Success
    case ExceedLimit
    case Failure
}

public enum OrderType {
    case Desc
    case Asc
}

public class PlaylistStore: RLMObject {
    dynamic var id:        String = ""
    dynamic var title:     String = ""
    dynamic var createdAt: Int64  = 0
    dynamic var updatedAt: Int64  = 0
    dynamic var number:    Float  = 0
    dynamic var tracks = RLMArray(objectClassName: TrackStore.className())

    public enum OrderBy {
        case CreatedAt(OrderType)
        case UpdatedAt(OrderType)
        case Title(OrderType)
        case Number(OrderType)
        var name: String {
            switch self {
            case CreatedAt: return "createdAt"
            case UpdatedAt: return "updatedAt"
            case Title:     return "title"
            case Number:    return "number"
            }
        }
        var ascending: Bool {
            switch self {
            case CreatedAt(let orderType): return orderType == .Asc
            case UpdatedAt(let orderType): return orderType == .Asc
            case Title(let orderType):     return orderType == .Asc
            case Number(let orderType):    return orderType == .Asc
            }
        }
    }

    public override class func primaryKey() -> String {
        return "id"
    }

    class var realm: RLMRealm {
        get {
            return RLMRealm.defaultRealm()
        }
    }

    internal class func removeTrackAtIndex(index: UInt, playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            try! realm.transactionWithBlock() {
                store.tracks.removeObjectAtIndex(index)
            }
        }
    }

    internal func insertTrack(trackStore: TrackStore, atIndex: UInt) -> PersistentResult {
        if Int(tracks.count) + 1 > Playlist.trackNumberLimit {
            return .ExceedLimit
        }
        do {
            try realm!.transactionWithBlock() {
                tracks.insertObject(trackStore, atIndex: atIndex)
            }
            return .Success
        } catch {
            return .Failure
        }
    }

    internal class func appendTracks(tracks: [Track], playlist: Playlist) -> PersistentResult {
        let trackStores: [TrackStore] = tracks.map({ track in
            if let trackStore = TrackStore.findBy(url: track.url) { return trackStore }
            else                                                  { return track.toStoreObject() }
        })

        if let store = findBy(id: playlist.id) {
            if Int(store.tracks.count) + trackStores.count > Playlist.trackNumberLimit {
                return .ExceedLimit
            }
            do {
                try realm.transactionWithBlock() {
                    store.tracks.addObjects(trackStores)
                }
                return .Success
            } catch {
                return .Failure
            }
        }
        return .Failure
    }

    internal class func create(playlist: Playlist) -> PersistentResult {
        if PlaylistStore.findAll().count+1 > Playlist.playlistNumberLimit {
            return .ExceedLimit
        }
        if let _ = findBy(id: playlist.id) { return .Failure }
        let store = playlist.toStoreObject()
        store.createdAt = NSDate().timestamp
        do {
            try realm.transactionWithBlock() {
                self.realm.addObject(store)
            }
            return .Success
        } catch {
            return .Failure
        }
    }

    internal class func save(playlist: Playlist) -> Bool {
        if let store = findBy(id: playlist.id) {
            try! realm.transactionWithBlock() {
                store.title = playlist.title
                store.updatedAt = NSDate().timestamp
            }
            return true
        } else {
            return false
        }
    }

    internal class func findAll(orderBy: OrderBy = OrderBy.CreatedAt(.Desc)) -> [Playlist] {
        var playlists: [Playlist] = []
        for store in PlaylistStore.allObjectsInRealm(realm).sortedResultsUsingProperty(orderBy.name, ascending: orderBy.ascending) {
            playlists.append(Playlist(store: store as! PlaylistStore))
        }
        return playlists
    }

    internal class func findBy(id id: String) -> PlaylistStore? {
        let results = PlaylistStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? PlaylistStore
        }
    }

    internal class func remove(playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            try! realm.transactionWithBlock() {
                self.realm.deleteObject(store)
            }
        }
    }

    internal class func removeAll() {
        try! realm.transactionWithBlock() {
            self.realm.deleteAllObjects()
        }
    }
}