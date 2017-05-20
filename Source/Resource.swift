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
    }
    public enum ItemType: String {
        case journal  = "journal"
        case topic    = "topic"
        case keyword  = "keyword"
        case tag      = "tag"
        case category = "category"
        case latest   = "latest"
        case hot      = "hot"
        case popular  = "popular"
    }
    public var resourceId:   String
    public var resourceType: ResourceType
    public var engagement:   Int
    public var itemType:     ItemType?
    public var item:         ResourceItem?
    public init(resourceId: String, resourceType: ResourceType, engagement: Int, itemType: ItemType?, item: ResourceItem?) {
        self.resourceId   = resourceId
        self.resourceType = resourceType
        self.engagement   = engagement
        self.itemType     = itemType
        self.item         = item
    }
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }
    public init(json: JSON) {
        resourceId   = json["resource_id"].stringValue
        resourceType = ResourceType(rawValue : json["resource_type"].stringValue) ?? .custom
        engagement   = json["engagement"].intValue
        itemType     = ItemType(rawValue: json["item_type"].stringValue)
        item         = ResourceItem(resourceType: resourceType, itemType: itemType, json: json["item"])
    }
}

public enum ResourceItem {
    case stream(FeedlyKit.Stream)
    case trackStream(FeedlyKit.Stream)
    case albumStream(FeedlyKit.Stream)
    case playlistStream(FeedlyKit.Stream)
    case entry(Entry)
    case track(Track)
    case album(Album)
    case playlist(ServicePlaylist)
    public init?(resourceType: Resource.ResourceType, itemType: Resource.ItemType?, json: JSON) {
        if json.type == .null { return nil }
        guard let itemType = itemType else { return nil }
        switch resourceType {
        case .stream:
            self = .stream(ResourceItem.buildStream(itemType:itemType, json: json))
        case .trackStream:
            self = .trackStream(ResourceItem.buildStream(itemType:itemType, json: json))
        case .albumStream:
            self = .albumStream(ResourceItem.buildStream(itemType:itemType, json: json))
        case .playlistStream:
            self = .playlistStream(ResourceItem.buildStream(itemType:itemType, json: json))
        case .entry:
            self = .entry(Entry(json: json))
        case .track:
            self = .track(Track(json: json))
        case .album:
            self = .album(Album(json: json))
        case .playlist:
            self = .playlist(ServicePlaylist(json: json))
        case .custom:
            return nil
        }
    }
    public static func buildStream(itemType: Resource.ItemType, json: JSON) -> FeedlyKit.Stream {
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
        case .latest:
            return Tag(json: json)
        case .hot:
            return Tag(json: json)
        case .popular:
            return Tag(json: json)
        }
    }
}
