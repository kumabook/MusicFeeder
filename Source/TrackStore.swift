//
//  TrackStore.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 2/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

open class TrackStore: RLMObject {
    @objc dynamic var id:           String = ""
    @objc dynamic var url:          String = ""
    @objc dynamic var providerRaw:  String = ""
    @objc dynamic var identifier:   String = ""
    @objc dynamic var title:        String = ""
    @objc dynamic var streamUrl:    String = ""
    @objc dynamic var thumbnailUrl: String = ""
    @objc dynamic var duration:     Int    = 0
    @objc dynamic var likesCount:   Int64  = 0
    @objc dynamic var entriesCount: Int64  = 0
    @objc dynamic var expiresAt:    Int64  = 0
    @objc dynamic var artist:       String = "" // FIXME


    @objc dynamic var entries              = RLMArray<EntryStore>(objectClassName: EntryStore.className())
    @objc dynamic var likers               = RLMArray<ProfileStore>(objectClassName: ProfileStore.className())

    class var realm: RLMRealm {
        return RLMRealm.default()
    }

    open override class func requiredProperties() -> [String] {
        return ["id", "url", "providerRaw", "identifier", "title", "streamUrl", "thumbnailUrl"]
    }

    override open class func primaryKey() -> String {
        return "url"
    }

    internal class func findOrCreate(_ track: Track) -> TrackStore? {
        if let store = findBy(url: track.url) {
            return store
        }
        return track.toStoreObject()
    }

    internal class func findBy(url: String) -> TrackStore? {
        let results = TrackStore.objects(in: realm, with: NSPredicate(format: "url = %@", url))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? TrackStore
        }
    }

    internal class func findBy(id: String) -> TrackStore? {
        let results = TrackStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? TrackStore
        }
    }


    internal class func findAll() -> [TrackStore] {
        let results = TrackStore.allObjects(in: realm)
        var trackStores: [TrackStore] = []
        for result in realizeResults(results) {
            trackStores.append(result as! TrackStore)
        }
        return trackStores
    }

    internal class func create(_ track: Track) -> Bool {
        if let _ = findBy(url: track.url) { return false }
        let store = track.toStoreObject()
        do {
            try realm.transaction() {
                self.realm.add(store)
            }
        } catch {
            return false
        }
        return true
    }

    internal class func save(_ track: Track) -> Bool {
        if let store = findBy(url: track.url) {
            try! realm.transaction() {
                if let title        = track.title                        { store.title        = title }
                if let audioUrl     = track.audioUrl?.absoluteString     { store.streamUrl    = audioUrl }
                if let thumbnailUrl = track.thumbnailUrl?.absoluteString { store.thumbnailUrl = thumbnailUrl }
            }
            return true
        } else {
            return false
        }
    }

    internal class func remove(_ track: TrackStore) {
        if let store = findBy(url: track.url) {
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
