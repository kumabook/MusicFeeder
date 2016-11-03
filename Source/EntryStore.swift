//
//  EntryStore.swift
//  MusicFeeder
//
//  Created by KumamotoHiroki on 10/4/15.
//  Copyright © 2015 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

extension Entry {
    convenience init(store: EntryStore) {
        self.init(id: store.id)
        id              = store.id
        title           = store.title
        author          = store.author
        crawled         = store.crawled
        recrawled       = store.recrawled
        published       = store.published
        updated         = store.updated
        unread          = store.unread
        engagement      = store.engagement
        actionTimestamp = store.actionTimestamp
        fingerprint     = store.fingerprint
        originId        = store.originId
        sid             = store.sid

        content         = store.content.map { Content(store: $0) }
        origin          = store.origin.map  { Origin(store: $0) }
        visual          = store.visual.map  { Visual(store: $0) }
        summary         = store.summary.map { Content(store: $0) }

        alternate  = realize(store.alternate).map  { return Link(store: $0 as! LinkStore) }
        keywords   = realize(store.keywords).map   { return ($0 as! KeywordStore).name }
        tags       = realize(store.tags).map       { return Tag(store: $0 as! TagStore) }
        categories = realize(store.categories).map { return Category(store: $0 as! CategoryStore) }
        enclosure  = realize(store.enclusure).map  { return Link(store: $0 as! LinkStore) }
    }
    func toStoreObject() -> EntryStore {
        let store = EntryStore()
        updateProperties(store)
        return store
    }
    func updateProperties(_ store: EntryStore) {
        store.id              = id
        store.title           = title
        store.author          = author
        store.crawled         = crawled
        store.recrawled       = recrawled
        store.published       = published
        store.updated         = updated ?? 0
        store.unread          = unread
        store.engagement      = engagement ?? 0
        store.actionTimestamp = actionTimestamp ?? 0
        store.fingerprint     = fingerprint
        store.originId        = originId
        store.sid             = sid

        store.content       = content?.toStoreObject()
        store.origin        = origin?.toStoreObject()
        store.visual        = visual?.toStoreObject()
        store.summary       = summary?.toStoreObject()

        store.alternate  = RLMArray(objectClassName: LinkStore.className())
        for item in alternate ?? [] { store.alternate.add(item.toStoreObject()) }
        store.keywords   = RLMArray(objectClassName: KeywordStore.className())
        for item in keywords  ?? [] { store.keywords.add(KeywordStore(name: item)) }
        store.tags       = RLMArray(objectClassName: TagStore.className())
        for item in tags      ?? [] { store.tags.add(item.toStoreObject()) }
        store.categories = RLMArray(objectClassName: CategoryStore.className())
        for item in categories      { store.categories.add(item.toStoreObject()) }
        store.enclusure  = RLMArray(objectClassName: LinkStore.className())
        for item in enclosure ?? [] { store.enclusure.add(item.toStoreObject()) }
    }
}

extension Content {
    convenience init(store: ContentStore) {
        self.init(direction: store.direction, content: store.content)
    }
    func toStoreObject() -> ContentStore {
        let store = ContentStore()
        store.direction = direction
        store.content   = content
        return store
    }
}

extension Link {
    convenience init(store: LinkStore) {
        self.init(href: store.href, type: store.type, length: store.length)
    }
    func toStoreObject() -> LinkStore {
        let store = LinkStore()
        store.href   = href
        store.type   = type
        store.length = length ?? 0
        return store
    }
}

extension Tag {
    convenience init(store: TagStore) {
        self.init(id: store.id, label: store.label)
    }

    func toStoreObject() -> TagStore {
        let store = TagStore()
        store.id    = id
        store.label = label
        return store
    }
}

extension Origin {
    convenience init(store: OriginStore) {
        self.init(streamId: store.streamId, title: store.title, htmlUrl: store.htmlUrl)
    }
    func toStoreObject() -> OriginStore {
        let store = OriginStore()
        store.streamId = streamId
        store.title    = title
        store.htmlUrl  = htmlUrl
        return store
    }
}

extension Visual {
    convenience init(store: VisualStore) {
        self.init(url: store.url, width: store.width, height: store.height, contentType: store.contentType)
    }
    func toStoreObject() -> VisualStore {
        let store = VisualStore()
        store.url         = url
        store.width       = width
        store.height      = height
        store.contentType = contentType
        return store
    }
}

public class ContentStore: RLMObject {
    dynamic var direction: String = ""
    dynamic var content:   String = ""
    public override class func requiredProperties() -> [String] {
        return ["direction", "content"]
    }
}
public class LinkStore: RLMObject {
    dynamic var href:   String = ""
    dynamic var type:   String = ""
    dynamic var length: Int    = 0
    public override class func requiredProperties() -> [String] {
        return ["href", "type"]
    }
}
public class TagStore:      RLMObject {
    dynamic var id:    String = ""
    dynamic var label: String = ""
    public override class func requiredProperties() -> [String] {
        return ["id", "label"]
    }
}
public class KeywordStore:  RLMObject {
    dynamic var name: String = ""
    override init() {
        super.init()
    }
    convenience init(name: String) {
        self.init()
        self.name = name
    }
    public override class func requiredProperties() -> [String] {
        return ["name"]
    }
}

public class OriginStore: RLMObject {
    dynamic var streamId: String = ""
    dynamic var title:    String = ""
    dynamic var htmlUrl:  String = ""
    public override class func requiredProperties() -> [String] {
        return ["streamId", "title", "htmlUrl"]
    }
}
public class VisualStore: RLMObject {
    dynamic var url:         String = ""
    dynamic var width:       Int    = 0
    dynamic var height:      Int    = 0
    dynamic var contentType: String = ""
    public override class func requiredProperties() -> [String] {
        return ["url", "contentType"]
    }
}

open class EntryStore: RLMObject {
    dynamic var id:              String = ""
    dynamic var title:           String?
    dynamic var author:          String?
    dynamic var crawled:         Int64         = 0
    dynamic var recrawled:       Int64         = 0
    dynamic var published:       Int64         = 0
    dynamic var updated:         Int64         = 0
    dynamic var unread:          Bool          = false
    dynamic var engagement:      Int           = 0
    dynamic var actionTimestamp: Int64         = 0
    dynamic var fingerprint:     String?
    dynamic var originId:        String?
    dynamic var sid:             String?
    dynamic var content:         ContentStore?
    dynamic var summary:         ContentStore?
    dynamic var origin:          OriginStore?
    dynamic var visual:          VisualStore?
    dynamic var alternate  = RLMArray(objectClassName: LinkStore.className())
    dynamic var keywords   = RLMArray(objectClassName: KeywordStore.className())
    dynamic var tags       = RLMArray(objectClassName: TagStore.className())
    dynamic var categories = RLMArray(objectClassName: CategoryStore.className())
    dynamic var enclusure  = RLMArray(objectClassName: LinkStore.className())

    class var realm: RLMRealm {
        get {
            return RLMRealm.default()
        }
    }

    override open class func primaryKey() -> String {
        return "id"
    }

    override open class func requiredProperties() -> [String] {
        return ["id"]
    }

    public class func findOrCreate(_ entry: Entry) -> EntryStore {
        if let store = findBy(id: entry.id) {
            return store
        }
        return entry.toStoreObject()
    }

    public class func findBy(id: String) -> EntryStore? {
        let results = EntryStore.objects(in: realm, with: NSPredicate(format: "id = %@", id))
        if results.count == 0 {
            return nil
        } else {
            return results[0] as? EntryStore
        }
    }

    public class func findAll() -> [EntryStore] {
        let results = EntryStore.allObjects(in: realm)
        var entryStores: [EntryStore] = []
        for result in realizeResults(results) {
            entryStores.append(result as! EntryStore)
        }
        return entryStores
    }

    public class func create(_ entry: Entry) -> Bool {
        if let _ = findBy(id: entry.id) { return false }
        let store = entry.toStoreObject()
        try! realm.transaction() {
            self.realm.add(store)
        }
        return true
    }

    public class func save(_ entry: Entry) -> Bool {
        if let store = findBy(id: entry.id) {
            try! realm.transaction() {
                entry.updateProperties(store)
            }
            return true
        } else {
            return false
        }
    }

    public class func remove(_ entry: EntryStore) {
        if let store = findBy(id: entry.id) {
            try! realm.transaction() {
                self.realm.delete(store)
            }
        }
    }

    public class func removeAll() {
        try! realm.transaction() {
            self.realm.deleteAllObjects()
        }
    }
}
