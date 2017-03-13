//
//  ServicePlaylist.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/12.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SwiftyJSON
import Breit
import FeedlyKit

public struct ServicePlaylist: Equatable, Hashable, ResponseObjectSerializable, ResponseCollectionSerializable {
    public fileprivate(set) var id:           String = ""
    public fileprivate(set) var provider:     Provider
    public fileprivate(set) var identifier:   String = ""
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
    public fileprivate(set) var entries:      [Entry]?
    public fileprivate(set) var entriesCount: Int64?
    
    public var hashValue: Int {
        return "\(provider):\(identifier)".hashValue
    }
    public static func collection(_ response: HTTPURLResponse, representation: Any) -> [ServicePlaylist]? {
        let json = JSON(representation)
        return json.arrayValue.map({ ServicePlaylist(json: $0) })
    }
    
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }
    
    public init(id: String, provider: Provider, url: String, identifier: String, title: String?) {
        self.id         = id
        self.provider   = provider
        self.url        = url
        self.identifier = identifier
        self.title      = title
    }

    public init(json: JSON) {
        id           = json["id"].stringValue
        provider     = Provider(rawValue: json["provider"].stringValue)!
        identifier   = json["identifier"].stringValue
        url          = json["url"].stringValue
        title        = json["title"].string
        description  = json["description"].string
        thumbnailUrl = json["thumbnail_url"].string.flatMap { URL(string: $0) }
        artworkUrl   = json["artwork_url"].string.flatMap { URL(string: $0) }
        state        = EnclosureState(rawValue: json["state"].stringValue)!
        likers       = []
        likesCount   = 0
        entries      = []
        publishedAt  = json["published_at"].string?.dateFromISO8601?.timestamp ?? 0
        updatedAt    = json["updated_at"].string?.dateFromISO8601?.timestamp ?? 0
        createdAt    = json["created_at"].string?.dateFromISO8601?.timestamp ?? 0

        // prefer to cache
        likers       = json["likers"].array?.map  { Profile(json: $0) }
        likesCount   = json["likesCount"].int64Value
        entries      = json["entries"].array?.map { Entry(json: $0) }
        entriesCount = json["likesCount"].int64Value
    }

    #if os(iOS)
    public func open() {
        if let url = URL(string: url) {
            UIApplication.shared.openURL(url)
        }
    }
    #endif
}

public func ==(lhs: ServicePlaylist, rhs: ServicePlaylist) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
