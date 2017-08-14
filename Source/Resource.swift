//
//  Resource.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/17.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SwiftyJSON
import FeedlyKit
import ReactiveSwift

public struct Resource: ResponseObjectSerializable {
    public enum ResourceType: String {
        case stream         = "stream"
        case trackStream    = "track_stream"
        case albumStream    = "album_stream"
        case playlistStream = "playlist_stream"
        case entry          = "entry"
        case track          = "track"
        case album          = "album"
        case playlist       = "playlist"
        case custom         = "custom"
        case mix            = "mix"
        case trackMix       = "track_mix"
        case albumMix       = "album_mix"
        case playlistMix    = "playlist_mix"
    }
    public enum ItemType: String {
        case feed      = "feed"
        case journal   = "journal"
        case topic     = "topic"
        case keyword   = "keyword"
        case tag       = "tag"
        case category  = "category"
        case entry     = "entry"
        case track     = "track"
        case album     = "album"
        case playlist  = "playlist"
        case globalTag = "global_tag"
    }
    public var resourceId:   String
    public var resourceType: ResourceType
    public var engagement:   Int
    public var itemType:     ItemType?
    public var item:         ResourceItem?
    public var options:      [String:Any]?

    public static let defaultResourceTypes: [String: ResourceType] = [
        "journal":  .stream,
        "topic":    .stream,
        "keyword":  .stream,
        "tag":      .stream,
        "category": .stream,
        "entry":    .entry,
        "track":    .track,
        "album":    .album,
        "playlist": .playlist
    ]

    public static func resourceType(resourceId: String) -> ResourceType {
        for key in defaultResourceTypes.keys {
            if resourceId.hasPrefix(key), let type = defaultResourceTypes[key] {
                return type
            }
        }
        return .custom
    }

    public static let defaultItemTypes: [String: ItemType] = [
        "feed":     .feed,
        "journal":  .journal,
        "topic":    .topic,
        "keyword":  .keyword,
        "tag":      .tag,
        "category": .category,
        "entry":    .entry,
        "track":    .track,
        "album":    .album,
        "playlist": .playlist
    ]

    public static func itemType(resourceId: String) -> ItemType? {
        for key in defaultItemTypes.keys {
            if resourceId.hasPrefix(key), let type = defaultItemTypes[key] {
                return type
            }
        }
        return nil
    }

    public func itemId() -> String {
        switch resourceType {
        case .entry:
            return resourceId.replace("entry/", withString: "")
        case .track:
            return resourceId.replace("track/", withString: "")
        case .album:
            return resourceId.replace("album/", withString: "")
        case .playlist:
            return resourceId.replace("playlist/", withString: "")
        default:
            return resourceId
        }
    }
    public init(resourceId: String, resourceType: ResourceType, engagement: Int, itemType: ItemType? = nil, item: ResourceItem? = nil, options: [String:Any]? = nil) {
        self.resourceId   = resourceId
        self.resourceType = resourceType
        self.engagement   = engagement
        self.itemType     = itemType
        self.item         = item
        self.options      = options
    }
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }
    public init(json: JSON) {
        self.init(json: json, itemJson: json["item"], optionsJson: json["options"])
    }
    public init(json: JSON, itemJson: JSON, optionsJson: JSON) {
        let id       = json["resource_id"].stringValue
        resourceId   = id
        resourceType = ResourceType(rawValue : json["resource_type"].stringValue) ?? Resource.resourceType(resourceId: id)
        engagement   = json["engagement"].intValue
        itemType     = ItemType(rawValue: json["item_type"].stringValue) ?? Resource.itemType(resourceId: id)
        item         = ResourceItem(resourceType: resourceType, itemType: itemType, item: itemJson, options: optionsJson)
        options      = optionsJson.dictionaryObject
    }
    public init(dictionary: [String:Any?]) {
        self.init(json: JSON(dictionary))
    }
    public func toJSON() -> [String:Any] {
        var v: [String:Any] = [
            "resource_id": resourceId,
            "resource_type": resourceType.rawValue
        ]
        if let itemType = itemType, let item = item {
            v["item_type"] = itemType.rawValue
            v["item"] = item.toJSON()
        }
        return v
    }
    public func fetchItem() -> SignalProducer<Resource, NSError> {
        guard let itemType = itemType else { return SignalProducer(value: self) }
        switch itemType {
        case .feed:
            return CloudAPIClient.shared.fetchFeed(feedId: resourceId).map {
                var resource = self
                resource.item = ResourceItem.stream($0, MixPeriod.default)
                return resource
                }
        case .journal:
            var resource = self
            if resource.item == nil {
                resource.item = ResourceItem.stream(Journal(label: resourceId.replace("journal/", withString: "")), MixPeriod.default)
            }
            return SignalProducer(value: resource)
        case .topic:
            var resource = self
            if resource.item == nil {
                resource.item = ResourceItem.stream(Topic(label: resourceId.replace("topic/", withString: "")), MixPeriod.default)
            }
            return SignalProducer(value: resource)
        case .keyword:
            var resource = self
            if resource.item == nil {
                resource.item = ResourceItem.stream(Feed(id: resourceId,
                                                      title: resourceId.replace("keyword/", withString: ""),
                                                description: "",
                                                subscribers: 0), MixPeriod.default)
            }
            return SignalProducer(value: resource)
        case .category, .tag, .globalTag:
            return SignalProducer(value: self)
        case .entry:
            return CloudAPIClient.shared.fetchEntry(entryId: itemId()).map {
                var resource = self
                resource.item = ResourceItem.entry($0)
                return resource
            }
        case .track:
            return CloudAPIClient.shared.fetchTrack(itemId()).map {
                var resource = self
                resource.item = ResourceItem.track($0)
                return resource
            }
        case .album:
            return CloudAPIClient.shared.fetchAlbum(itemId()).map {
                var resource = self
                resource.item = ResourceItem.album($0)
                return resource
            }
        case .playlist:
            return CloudAPIClient.shared.fetchPlaylist(itemId()).map {
                var resource = self
                resource.item = ResourceItem.playlist($0)
                return resource
            }
        }
    }
}

public enum ResourceItem {
    case stream(FeedlyKit.Stream, MixPeriod)
    case trackStream(FeedlyKit.Stream, MixPeriod)
    case albumStream(FeedlyKit.Stream, MixPeriod)
    case playlistStream(FeedlyKit.Stream, MixPeriod)
    case mix(FeedlyKit.Stream, MixPeriod, MixType)
    case trackMix(FeedlyKit.Stream, MixPeriod, MixType)
    case albumMix(FeedlyKit.Stream, MixPeriod, MixType)
    case playlistMix(FeedlyKit.Stream, MixPeriod, MixType)
    case entry(Entry)
    case track(Track)
    case album(Album)
    case playlist(ServicePlaylist)
    public init?(resourceType: Resource.ResourceType, itemType: Resource.ItemType?, item: JSON, options: JSON) {
        if item.type == .null { return nil }
        guard let itemType = itemType else { return nil }
        switch resourceType {
        case .stream:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .stream(stream, ResourceItem.buildMixPeriod(json: options))
        case .trackStream:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .trackStream(stream, ResourceItem.buildMixPeriod(json: options))
        case .albumStream:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .albumStream(stream, ResourceItem.buildMixPeriod(json: options))
        case .playlistStream:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .playlistStream(stream, ResourceItem.buildMixPeriod(json: options))
        case .mix:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .mix(stream,
                        ResourceItem.buildMixPeriod(json: options),
                        ResourceItem.buildMixType(json: options))
        case .trackMix:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .trackMix(stream,
                             ResourceItem.buildMixPeriod(json: options),
                             ResourceItem.buildMixType(json: options))
        case .albumMix:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .albumMix(stream,
                             ResourceItem.buildMixPeriod(json: options),
                             ResourceItem.buildMixType(json: options))
        case .playlistMix:
            guard let stream = ResourceItem.buildStream(itemType:itemType, json: item) else { return nil }
            self = .playlistMix(stream,
                                ResourceItem.buildMixPeriod(json: options),
                                ResourceItem.buildMixType(json: options))
        case .entry:
            self = .entry(Entry(json: item))
        case .track:
            self = .track(Track(json: item))
        case .album:
            self = .album(Album(json: item))
        case .playlist:
            self = .playlist(ServicePlaylist(json: item))
        case .custom:
            return nil
        }
    }
    public func toJSON() -> [String: Any?] {
        switch self {
        case .entry(let entry): return entry.toJSON()
        default: return [:]
        }
    }
    public var thumbnailURL: URL? {
        switch self {
        case .entry(let e):    return e.thumbnailURL
        case .track(let t):    return t.thumbnailURL
        case .album(let a):    return a.artworkUrl
        case .playlist(let p): return p.artworkUrl
        case .stream(let s, _),
             .trackStream(let s, _),
             .albumStream(let s, _),
             .playlistStream(let s, _),
             .mix(let s, _, _),
             .trackMix(let s, _, _),
             .albumMix(let s, _, _),
             .playlistMix(let s, _, _):
            return s.thumbnailURL
        }
    }
    public var title: String? {
        switch self {
        case .entry(let e):    return e.title
        case .track(let t):    return t.title
        case .album(let a):    return a.title
        case .playlist(let p): return p.title
        case .stream(let s, _),
             .trackStream(let s, _),
             .albumStream(let s, _),
             .playlistStream(let s, _),
             .mix(let s, _, _),
             .trackMix(let s, _, _),
             .albumMix(let s, _, _),
             .playlistMix(let s, _, _):
            return s.streamTitle
        }
    }
    public var stream: FeedlyKit.Stream? {
        switch self {
        case .stream(let stream, _):         return stream
        case .trackStream(let stream, _):    return stream
        case .albumStream(let stream, _):    return stream
        case .playlistStream(let stream, _): return stream
        case .mix(let stream, _, _):         return stream
        case .trackMix(let stream, _, _):    return stream
        case .albumMix(let stream, _, _):    return stream
        case .playlistMix(let stream, _, _): return stream
        default:                             return nil
        }
    }
    public static func buildStream(itemType: Resource.ItemType, json: JSON) -> FeedlyKit.Stream? {
        switch itemType {
        case .journal:
            return Journal(json: json)
        case .topic:
            return Topic(json: json)
        case .keyword:
            return Tag(json: json)
        case .tag:
            return Tag(json: json)
        case .category:
            return FeedlyKit.Category(json: json)
        case .globalTag:
            return Tag(json: json)
        default:
            return nil
        }
    }
    public static func buildMixPeriod(json: JSON) -> MixPeriod {
        return MixPeriod(rawValue: json["period"].stringValue) ?? .default
    }
    public static func buildMixType(json: JSON) -> MixType {
        return MixType(rawValue: json["type"].stringValue) ?? .hot
    }
}
