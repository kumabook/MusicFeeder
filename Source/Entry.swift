//
//  Entry.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit

var StoredPropertyKeyForTracks:    UInt8 = 0
var StoredPropertyKeyForAlbums:    UInt8 = 1
var StoredPropertyKeyForPlaylists: UInt8 = 2

extension Entry {
    public var url: NSURL? {
        if let alternate = self.alternate {
            if alternate.count > 0 {
                return NSURL(string: alternate[0].href)
            }
        }
        return nil
    }

    public var tracks: [Track] {
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
    public var passedTime: String {
        return published.date.passedTime
    }

    public func toPlaylist() -> Playlist {
        if let t = title {
            return Playlist(id: "playlist_\(id)", title: t, tracks: tracks)
        } else {
            return Playlist(id: "playlist_\(id)", title: "", tracks: tracks)
        }
    }
}
