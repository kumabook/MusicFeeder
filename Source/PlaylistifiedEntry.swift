//
//  PlaylistifiedEntry.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/12.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SwiftyJSON
import Breit
import FeedlyKit

public struct PlaylistifiedEntry: Equatable, Hashable, ResponseObjectSerializable, ResponseCollectionSerializable {
    public fileprivate(set) var id:  String
    public fileprivate(set) var url: String
    public fileprivate(set) var title: String?
    public fileprivate(set) var description: String?
    public fileprivate(set) var visualUrl:   URL?
    public fileprivate(set) var locale:      String?
    public fileprivate(set) var createdAt:   Int64 = 0
    public fileprivate(set) var updatedAt:   Int64 = 0
    public fileprivate(set) var tracks:      [Track]
    public fileprivate(set) var playlists:   [ServicePlaylist]
    public fileprivate(set) var albums:      [Album]

    public var hashValue: Int {
        return id.hashValue
    }
    public static func collection(_ response: HTTPURLResponse, representation: Any) -> [PlaylistifiedEntry]? {
        let json = JSON(representation)
        return json.arrayValue.map({ PlaylistifiedEntry(json: $0) })
    }
    
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    public init(json: JSON) {
        id          = json["id"].stringValue
        url         = json["url"].stringValue
        title       = json["title"].string
        description = json["description"].string
        visualUrl   = json["thumbnail_url"].string.flatMap { URL(string: $0) }
        locale      = json["locale"].string
        updatedAt   = json["updated_at"].string?.dateFromISO8601?.timestamp ?? 0
        createdAt   = json["created_at"].string?.dateFromISO8601?.timestamp ?? 0
        tracks      = json["tracks"].array?.map    { Track(json: $0) }           ?? []
        playlists   = json["playlists"].array?.map { ServicePlaylist(json: $0) } ?? []
        albums      = json["albums"].array?.map    { Album(json: $0) }           ?? []
    }
}

public func ==(lhs: PlaylistifiedEntry, rhs: PlaylistifiedEntry) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
