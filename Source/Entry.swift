//
//  Entry.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import FeedlyKit

var StoredPropertyKeyForTracks:    UInt8 = 0
var StoredPropertyKeyForAlbums:    UInt8 = 1
var StoredPropertyKeyForPlaylists: UInt8 = 2

var StoredPropertyKeyForIsSaved:   UInt8 = 4
var StoredPropertyKeyForIsLiked:   UInt8 = 5
var StoredPropertyKeyForIsRead:    UInt8 = 6

var StoredPropertyKeyForSavedCount: UInt8 = 7
var StoredPropertyKeyForLikesCount: UInt8 = 8
var StoredPropertyKeyForReadCount:  UInt8 = 9

var StoredPropertyKeyForPlaylist:           UInt8 = 10
var StoredPropertyKeyForPlaylistifiedEntry: UInt8 = 11

extension Entry {
    public static func setupHookFunctions() {
        Entry.instanceDidInitialize = { (entry: Entry, json: JSON) in
            entry.initExtentedProperties(json: json)
        }
    }
    public func initExtentedProperties(json: JSON) {
        isLiked    = json["is_liked"].bool
        isSaved    = json["is_saved"].bool
        likesCount = json["likes_count"].intValue
        savedCount = json["saved_count"].intValue
        readCount  = json["read_count"].intValue
    }
    public var isSaved: Bool? {
        get {
            guard let saved = objc_getAssociatedObject(self, &StoredPropertyKeyForIsSaved) as? Bool? else {
                return nil
            }
            return saved
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForIsSaved, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    public var isLiked: Bool? {
        get {
            guard let liked = objc_getAssociatedObject(self, &StoredPropertyKeyForIsLiked) as? Bool? else {
                return nil
            }
            return liked
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForIsLiked, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    public var savedCount: Int {
        get {
            guard let count = objc_getAssociatedObject(self, &StoredPropertyKeyForSavedCount) as? Int else {
                return 0
            }
            return count
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForSavedCount, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    public var likesCount: Int {
        get {
            guard let count = objc_getAssociatedObject(self, &StoredPropertyKeyForLikesCount) as? Int else {
                return 0
            }
            return count
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForLikesCount, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    public var readCount: Int {
        get {
            guard let count = objc_getAssociatedObject(self, &StoredPropertyKeyForReadCount) as? Int else {
                return 0
            }
            return count
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForReadCount, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var url: URL? {
        if let alternate = self.alternate {
            if alternate.count > 0 {
                return URL(string: alternate[0].href)
            }
        }
        return nil
    }

    public var tracks: [Track] {
        get {
            if let storedTracks = self.storedTracks {
                return storedTracks
            }
            self.storedTracks = enclosure.map {
                $0.filter { $0.type.contains("application/json") }.flatMap {
                    Track(urlString: $0.href).map { [$0] } ?? []
                }
            }
            return self.storedTracks ?? []
        }
        set {
            storedTracks = newValue
        }
    }

    fileprivate var storedTracks: [Track]? {
        get {
            guard let tracks = objc_getAssociatedObject(self, &StoredPropertyKeyForTracks) as? [Track] else {
                return nil
            }
            return tracks
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForTracks, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var albums: [Album] {
        get {
            if let storedAlbums = self.storedAlbums {
                return storedAlbums
            }
            self.storedAlbums = enclosure.map {
                $0.filter { $0.type.contains("application/json") }.flatMap {
                    Album(urlString: $0.href).map { [$0] } ?? []
                }
            }
            return self.storedAlbums ?? []
        }
        set {
            storedAlbums = newValue
        }
    }

    fileprivate var storedAlbums: [Album]? {
        get {
            guard let albums = objc_getAssociatedObject(self, &StoredPropertyKeyForAlbums) as? [Album] else {
                return nil
            }
            return albums
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForAlbums, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var playlists: [ServicePlaylist] {
        get {
            if let storedPlaylists = self.storedPlaylists {
                return storedPlaylists
            }
            self.storedPlaylists = enclosure.map {
                $0.filter { $0.type.contains("application/json") }.flatMap {
                    ServicePlaylist(urlString: $0.href).map { [$0] } ?? []
                }
            }
            return self.storedPlaylists ?? []
        }
        set {
            storedPlaylists = newValue
        }
    }

    fileprivate var storedPlaylists: [ServicePlaylist]? {
        get {
            guard let playlists = objc_getAssociatedObject(self, &StoredPropertyKeyForPlaylists) as? [ServicePlaylist] else {
                return nil
            }
            return playlists
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForPlaylists, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var audioTracks: [Track] {
        return enclosure.map {
            $0.filter { $0.type.contains("audio") }.map {
                Track(id: "", provider: .raw, url: $0.href, identifier: $0.href, title: self.title)
            }
        } ?? []
    }

    internal func toPlaylist() -> Playlist {
        if let t = title {
            return Playlist(id: "playlist_\(id)", title: t, tracks: tracks)
        } else {
            return Playlist(id: "playlist_\(id)", title: "", tracks: tracks)
        }
    }

    public var playlist: Playlist? {
        get {
            return storedPlaylist
        }
        set {
            storedPlaylist = newValue
        }
    }

    internal var storedPlaylist: Playlist? {
        get {
            guard let playlist = objc_getAssociatedObject(self, &StoredPropertyKeyForPlaylist) as? Playlist else {
                return nil
            }
            return playlist
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForPlaylist, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public var playlistifiedEntry: PlaylistifiedEntry? {
        get {
            return storedPlaylistifiedEntry
        }
        set {
            storedPlaylistifiedEntry = newValue
        }
    }

    public func updateWithPlaylistifiedEntry(_ playlistifiedEntry: PlaylistifiedEntry) {
        tracks                  = playlistifiedEntry.tracks
        albums                  = playlistifiedEntry.albums
        playlists               = playlistifiedEntry.playlists
        title                   = title ?? playlistifiedEntry.title
        self.playlistifiedEntry = playlistifiedEntry
    }

    internal var storedPlaylistifiedEntry: PlaylistifiedEntry? {
        get {
            guard let playlistifiedEntry = objc_getAssociatedObject(self, &StoredPropertyKeyForPlaylistifiedEntry) as? PlaylistifiedEntry else {
                return nil
            }
            return playlistifiedEntry
        }
        set {
            objc_setAssociatedObject(self, &StoredPropertyKeyForPlaylistifiedEntry, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    public func updateExtentedProperties(_ entry: Entry) {
        isLiked    = entry.isLiked
        isSaved    = entry.isSaved
        likesCount = entry.likesCount
        savedCount = entry.savedCount
        readCount  = entry.readCount
    }
    open func toJSON() -> [String: Any?] {
        return [
        "id":              id,
        "title":           title,
        "content":         content?.toJSON(),
        "summary":         summary?.toJSON(),
        "author":          author,
        "crawled":         crawled,
        "recrawled":       recrawled,
        "published":       published,
        "updated":         updated,
        "alternate":       alternate?.map { $0.toJSON() },
        "origin":          origin.map { $0.toJSON() },
        "keywords":        keywords,
        "visual":          visual?.toJSON(),
        "unread":          unread,
        "tags":            tags?.map { $0.toJSON() },
        "categories":      categories.map { $0.toJSON() },
        "engagement":      engagement,
        "actionTimestamp": actionTimestamp,
        "enclosure":       enclosure?.map { $0.toJSON() },
        "fingerprint":     fingerprint,
        "originId":        originId,
        "sid":             sid,
        ]
    }
}

extension Content {
    public func toJSON() -> [String: Any] {
        return [
            "direction": direction,
            "content":   content,
        ]
    }
}

extension Tag {
    public func toJSON() -> [String: Any?] {
        return [
            "id":          id,
            "label":       label,
            "description": description,
        ]
    }
}

extension FeedlyKit.Category {
    public func toJSON() -> [String: Any?] {
        return [
            "id":          id,
            "label":       label,
            "description": description,
        ]
    }
}

extension Link {
    public func toJSON() -> [String: Any?] {
        return [
            "href":   href,
            "type":   type,
            "length": length,
        ]
    }
}

extension Origin {
    public func toJSON() -> [String: Any?] {
        return [
            "streamId": streamId,
            "title":    title,
            "htmlUrl":  htmlUrl,
        ]
    }
}

extension Visual {
    public func toJSON() -> [String: Any?] {
        return [
            "url":         url,
            "width":       width,
            "height":      height,
            "contentType": contentType,
        ]
    }
}
