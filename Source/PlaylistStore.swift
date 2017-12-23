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

/*
extension RLMArray: Sequence {
    public func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(self)
    }
}
extension RLMResults: Sequence {
    public func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(self)
    }
}
*/

func realize<O>(_ array: RLMArray<O>) -> [O] {
    var items: [O] = []
    for i in 0..<array.count {
        items.append(array.object(at: i))
    }
    return items
}

func realizeResults<O>(_ results: RLMResults<O>) -> [O] {
    var items: [O] = []
    for i in 0..<results.count {
        items.append(results.object(at: i))
    }
    return items    
}

public enum PersistentResult {
    case success
    case exceedLimit
    case failure
}

public enum OrderType {
    case desc
    case asc
}

public enum OrderBy {
    case createdAt(OrderType)
    case updatedAt(OrderType)
    case title(OrderType)
    case number(OrderType)
    var name: String {
        switch self {
        case .createdAt: return "createdAt"
        case .updatedAt: return "updatedAt"
        case .title:     return "title"
        case .number:    return "number"
        }
    }
    var ascending: Bool {
        switch self {
        case .createdAt(let orderType): return orderType == .asc
        case .updatedAt(let orderType): return orderType == .asc
        case .title(let orderType):     return orderType == .asc
        case .number(let orderType):    return orderType == .asc
        }
    }
}

open class PlaylistStore: RLMObject {
    @objc dynamic var id:        String = ""
    @objc dynamic var title:     String = ""
    @objc dynamic var createdAt: Int64  = 0
    @objc dynamic var updatedAt: Int64  = 0
    @objc dynamic var number:    Float  = 0
    @objc dynamic var tracks = RLMArray<TrackStore>(objectClassName: TrackStore.className())

    open override class func primaryKey() -> String {
        return "id"
    }

    open override class func requiredProperties() -> [String] {
        return ["id", "title"]
    }

    class var realm: RLMRealm {
        get {
            return RLMRealm.default()
        }
    }

    internal class func removeTrackAtIndex(_ index: UInt, playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            try! realm.transaction() {
                store.tracks.removeObject(at: index)
            }
        }
    }

    internal func insertTrack(_ trackStore: TrackStore, atIndex: UInt) -> PersistentResult {
        if Int(tracks.count) + 1 > Playlist.trackNumberLimit {
            return .exceedLimit
        }
        do {
            try PlaylistStore.realm.transaction() {
                tracks.insert(trackStore, at: atIndex)
            }
            return .success
        } catch {
            return .failure
        }
    }

    internal class func appendTracks(_ tracks: [Track], playlist: Playlist) -> PersistentResult {
        let trackStores: [TrackStore] = tracks.map({ track in
            if let trackStore = TrackStore.findBy(url: track.url) { return trackStore }
            else                                                  { return track.toStoreObject() }
        })

        if let store = findBy(id: playlist.id) {
            if Int(store.tracks.count) + trackStores.count > Playlist.trackNumberLimit {
                return .exceedLimit
            }
            do {
                try realm.transaction() {
                    store.tracks.addObjects(trackStores as NSFastEnumeration)
                }
                return .success
            } catch {
                return .failure
            }
        }
        return .failure
    }

    internal func moveTrackAtIndex(_ sourceIndex: UInt, toIndex: UInt) -> PersistentResult {
        do {
            try PlaylistStore.realm.transaction() {
                tracks.moveObject(at: sourceIndex, to: toIndex)
            }
            return .success
        } catch {
            return .failure
        }
    }

    internal class func create(_ playlist: Playlist) -> PersistentResult {
        if Int(PlaylistStore.findAll().count+1) > Playlist.playlistNumberLimit {
            return .exceedLimit
        }
        if let _ = findBy(id: playlist.id) { return .failure }
        let store = playlist.toStoreObject()
        store.createdAt = Date().timestamp
        store.number    = Float(PlaylistStore.findAll().count)
        do {
            try realm.transaction() {
                self.realm.add(store)
            }
            return .success
        } catch {
            return .failure
        }
    }

    internal class func save(_ playlist: Playlist) -> Bool {
        if let store = findBy(id: playlist.id) {
            try! realm.transaction() {
                store.title = playlist.title
                store.number = playlist.number
                store.updatedAt = Date().timestamp
            }
            return true
        } else {
            return false
        }
    }

    internal class func findAll(_ orderBy: OrderBy = OrderBy.number(.desc)) -> RLMResults<PlaylistStore> {
        return PlaylistStore.allObjects(in: realm).sortedResults(usingKeyPath: orderBy.name, ascending: orderBy.ascending) as! RLMResults<PlaylistStore>
    }

    internal class func findBy(id: String) -> PlaylistStore? {
        let results = PlaylistStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? PlaylistStore
        }
    }

    internal class func remove(_ playlist: Playlist) {
        if let store = findBy(id: playlist.id) {
            try! realm.transaction() {
                self.realm.delete(store)
            }
        }
    }

    internal class func removeAll() {
        try! realm.transaction() {
            self.realm.deleteAllObjects()
        }
    }
}
