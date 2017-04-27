//
//  Album.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/12.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SwiftyJSON
import Breit
import FeedlyKit

public final class Album: Equatable, Hashable, Enclosure {
    public static var resourceName:           String = "albums"
    public static var idListKey:              String = "albumIds"
    public fileprivate(set) var id:           String = ""
    public fileprivate(set) var provider:     Provider
    public fileprivate(set) var identifier:   String = ""
    public fileprivate(set) var owner_id:     String?
    public fileprivate(set) var owner_name:   String?
    public fileprivate(set) var url:          String = ""
    public fileprivate(set) var title:        String?
    public fileprivate(set) var description:  String?
    public fileprivate(set) var thumbnailUrl: URL?
    public fileprivate(set) var artworkUrl:   URL?
    public fileprivate(set) var publishedAt:  Int64 = 0
    public fileprivate(set) var createdAt:    Int64 = 0
    public fileprivate(set) var updatedAt:    Int64 = 0
    public fileprivate(set) var state:        EnclosureState = .alive
    
    public fileprivate(set) var likers:       [Profile]?
    public fileprivate(set) var likesCount:   Int64?
    public fileprivate(set) var playCount:    Int64?
    public fileprivate(set) var entries:      [Entry]?
    public fileprivate(set) var entriesCount: Int64?

    public                  var isLiked:      Bool?
    public                  var isSaved:      Bool?
    public                  var isPlayed:     Bool?
    
    public var hashValue: Int {
        return "\(provider):\(identifier)".hashValue
    }

    public required init?(urlString: String) {
        var dic      = Album.parseURI(uri: urlString)
        if dic["type"] != "albums" {
            return nil
        }
        id           = dic["id"] ?? ""
        provider     = dic["provider"].flatMap { Provider(rawValue: $0) } ?? Provider.youTube
        identifier   = dic["identifier"] ?? ""
        owner_id     = dic["owner_id"]
        owner_name   = dic["onwer_name"]
        url          = dic["url"] ?? urlString
        title        = dic["title"] ?? ""
        description  = dic["description"] ?? ""
        thumbnailUrl = dic["thumbnail_url"].flatMap { URL(string: $0) }
        artworkUrl   = dic["artwork_url"].flatMap { URL(string: $0) }
        publishedAt  = dic["published_at"].flatMap { $0.dateFromISO8601?.timestamp } ?? 0
        createdAt    = dic["updated_at"].flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        updatedAt    = dic["created_at"].flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        state        = dic["state"].flatMap { EnclosureState(rawValue: $0) } ?? EnclosureState.alive

        likesCount   = dic["likes_count"].flatMap { Int64($0) }
        playCount    = dic["play_count"].flatMap { Int64($0) }
        entriesCount = dic["entries_count"].flatMap { Int64($0) }

        isLiked      = dic["is_liked"].flatMap { $0 == "true" }
        isSaved      = dic["is_saved"].flatMap { $0 == "true" }
        isPlayed     = dic["is_played"].flatMap { $0 == "true" }
    }

    public static func collection(_ response: HTTPURLResponse, representation: Any) -> [Album]? {
        let json = JSON(representation)
        return json.arrayValue.map({ Album(json: $0) })
    }
    
    public convenience required init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }
    
    public init(id: String, provider: Provider, identifier: String, url: String,
                title: String? = nil, description: String? = nil,
                owner_id: String? = nil, owner_name: String?,
                thumbnailUrl: URL? = nil, artworkUrl: URL? = nil,
                publishedAt: Int64 = 0, createdAt: Int64 = 0, updatedAt: Int64 = 0,
                state: EnclosureState = .alive,
                isLiked: Bool? = nil, isSaved: Bool? = nil, isPlayed: Bool? = nil) {
        self.id           = id
        self.provider     = provider
        self.identifier   = identifier
        self.url          = url
        self.title        = title
        self.description  = description
        self.owner_id     = owner_id
        self.owner_name   = owner_name
        self.thumbnailUrl = thumbnailUrl
        self.artworkUrl   = artworkUrl
        self.publishedAt  = publishedAt
        self.createdAt    = createdAt
        self.updatedAt    = updatedAt
        self.state        = state
        self.isLiked      = isLiked
        self.isSaved      = isSaved
        self.isPlayed     = isPlayed
    }
    
    public required init(json: JSON) {
        id           = json["id"].stringValue
        provider     = Provider(rawValue: json["provider"].stringValue)!
        identifier   = json["identifier"].stringValue
        owner_id     = json["owner_id"].string
        owner_name   = json["onwer_name"].string
        url          = json["url"].stringValue
        title        = json["title"].string
        description  = json["description"].string
        thumbnailUrl = json["thumbnail_url"].string.flatMap { URL(string: $0) }
        artworkUrl   = json["artwork_url"].string.flatMap { URL(string: $0) }
        state        = EnclosureState(rawValue: json["state"].stringValue)!
        publishedAt  = json["published_at"].string?.dateFromISO8601?.timestamp ?? 0
        updatedAt    = json["updated_at"].string?.dateFromISO8601?.timestamp ?? 0
        createdAt    = json["created_at"].string?.dateFromISO8601?.timestamp ?? 0
        
        likers       = json["likers"].array?.map  { Profile(json: $0) }
        likesCount   = json["likes_count"].int64Value
        playCount    = json["play_count"].int64Value
        entries      = json["entries"].array?.map { Entry(json: $0) }
        entriesCount = json["likes_count"].int64Value

        isLiked      = json["is_liked"].bool
        isSaved      = json["is_saved"].bool
        isPlayed     = json["is_played"].bool
    }
    #if os(iOS)
    public func open() {
        if let url = URL(string: url) {
            UIApplication.shared.openURL(url)
        }
    }
    #endif
}

public func ==(lhs: Album, rhs: Album) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
