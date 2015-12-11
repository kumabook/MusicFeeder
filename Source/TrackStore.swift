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

public class TrackStore: RLMObject {
    dynamic var url:          String = ""
    dynamic var providerRaw:  String = ""
    dynamic var identifier:   String = ""
    dynamic var title:        String = ""
    dynamic var streamUrl:    String = ""
    dynamic var thumbnailUrl: String = ""
    dynamic var duration:     Int = 0

    class var realm: RLMRealm {
        return RLMRealm.defaultRealm()
    }

    public override class func requiredProperties() -> [AnyObject] {
        return ["url", "providerRaw", "identifier", "title", "streamUrl", "thumbnailUrl"]
    }

    override public class func primaryKey() -> String {
        return "url"
    }

    internal class func findOrCreate(track: Track) -> TrackStore? {
        if let store = findBy(url: track.url) {
            return store
        }
        return track.toStoreObject()
    }

    internal class func findBy(url url: String) -> TrackStore? {
        let results = TrackStore.objectsInRealm(realm, withPredicate: NSPredicate(format: "url = %@", url))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? TrackStore
        }
    }

    internal class func findAll() -> [TrackStore] {
        let results = TrackStore.allObjectsInRealm(realm)
        var trackStores: [TrackStore] = []
        for result in results {
            trackStores.append(result as! TrackStore)
        }
        return trackStores
    }

    internal class func create(track: Track) -> Bool {
        if let _ = findBy(url: track.url) { return false }
        let store = track.toStoreObject()
        try! realm.transactionWithBlock() {
            self.realm.addObject(store)
        }
        return true
    }

    internal class func save(track: Track) -> Bool {
        if let store = findBy(url: track.url) {
            try! realm.transactionWithBlock() {
                if let title        = track.title                        { store.title        = title }
                if let streamUrl    = track.streamUrl?.absoluteString    { store.streamUrl    = streamUrl }
                if let thumbnailUrl = track.thumbnailUrl?.absoluteString { store.thumbnailUrl = thumbnailUrl }
            }
            return true
        } else {
            return false
        }
    }

    internal class func remove(track: TrackStore) {
        if let store = findBy(url: track.url) {
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