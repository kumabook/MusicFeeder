//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveSwift
import Result
import PlayerKit
import Breit
import SoundCloudKit
import Alamofire
import FeedlyKit
import SDWebImage
#if os(iOS)
import UIKit
import MediaPlayer
#endif

final public class Track: PlayerKit.Track, Equatable, Hashable, Enclosure {
    public static var thumbnailImageSize: CGSize = CGSize(width: 128, height: 128)
    public static var artworkImageSize: CGSize = CGSize(width: 512, height: 512)
    public static var resourceName: String = "tracks"
    public static var idListKey:    String = "trackIds"
    fileprivate static let userDefaults = UserDefaults.standard
    public static var youtubeAPIClient: YouTubeAPIClient?
    public static var appleMusicCurrentCountry: String? = nil
    public static var isSpotifyPremiumUser: Bool = false
    public static var canPlayYouTubeWithAVPlayer: Bool {
        return Track.youtubeAPIClient != nil
    }
    public static var youTubeVideoQuality: YouTubeVideoQuality {
        get {
            if let quality = YouTubeVideoQuality(rawValue: Int64(userDefaults.integer(forKey: "youtube_video_quality"))) {
                return quality
            } else {
                return YouTubeVideoQuality.medium360
            }
        }
        set(quality) {
            userDefaults.set(Int(quality.rawValue), forKey: "youtube_video_quality")
        }
    }
    public static func isExtVideo(ext: String) -> Bool {
        return ["mp4", "m4v", "3gp", "mov"].contains(ext)
    }

    public enum Status {
        case `init`
        case cache
        case loading
        case dirty
        case available
        case unavailable
    }
    public fileprivate(set) var id:           String
    public fileprivate(set) var provider:     Provider
    public fileprivate(set) var identifier:   String

    public fileprivate(set) var url:          String
    public fileprivate(set) var entries:      [Entry]?
    public fileprivate(set) var entriesCount: Int64?
    public fileprivate(set) var title:        String?
    public fileprivate(set) var thumbnailUrl: URL?
    public fileprivate(set) var artworkUrl:   URL?
    public fileprivate(set) var audioUrl:     URL?
    public fileprivate(set) var duration:     TimeInterval
    public fileprivate(set) var likesCount:   Int64?
    public fileprivate(set) var likers:       [Profile]?
    public fileprivate(set) var savedCount:   Int64?
    public fileprivate(set) var playCount:    Int64?
    public fileprivate(set) var expiresAt:    Int64
    public fileprivate(set) var ownerId:      String?
    public fileprivate(set) var ownerName:    String?
    
    public fileprivate(set) var publishedAt:  Int64
    public fileprivate(set) var updatedAt:    Int64
    public fileprivate(set) var createdAt:    Int64
    public fileprivate(set) var state:        EnclosureState
    public                  var isLiked:      Bool?
    public                  var isSaved:      Bool?
    public                  var isPlayed:     Bool?
    #if os(iOS)
    public var mediaItem: MPMediaItem?
    #endif
    public var playerType: PlayerType {
        switch provider {
        case .appleMusic:
            if let c = country, c.lowercased() == Track.appleMusicCurrentCountry?.lowercased() {
                return .appleMusic
            }
            return .normal
        case .spotify:    return Track.isSpotifyPremiumUser ? .spotify : .normal
        case .youTube:    return Track.canPlayYouTubeWithAVPlayer ? .normal : .youtube
        default:          return .normal
        }
    }
    public var isValid: Bool {
        switch provider {
        case .youTube:
            return true
        case .appleMusic:
            return country?.localize() == Track.appleMusicCurrentCountry?.localize() || audioUrl != nil
        case .spotify:
            return spotifyURI != nil
        default:
            return streamURL != nil
        }
    }
    public var canPlayBackground: Bool {
        return playerType != .youtube
    }
    public var country: String? {
        if let country = _country {
            return country
        }
        let pattern = "\\/geo\\.itunes\\.apple\\.com\\/([a-zA-Z]+)\\/"
        let strings = url.matchingStrings(regex: pattern)
        _country = strings.get(0)?.get(1) ?? "none"
        return _country
    }
    fileprivate var _country: String?
    public var streamURL: URL? {
        switch provider {
        case  .appleMusic:
            return audioUrl
        case .spotify:
            return audioUrl
        case .youTube:
            return youtubeVideo?.streamURLs[Track.youTubeVideoQuality.key] ?? audioUrl
        case .soundCloud:
            return soundcloudTrack.flatMap { URL(string: $0.streamUrl + "?client_id=" + APIClient.shared.clientId) } ??
                audioUrl.flatMap { URL(string: $0.absoluteString + "?client_id=" + APIClient.shared.clientId) }
        case .custom:
            return audioUrl
        case .raw:
            return audioUrl
        }
    }
    public var appleMusicID: String? {
        switch provider {
        case  .appleMusic: return identifier
        default:           return nil
        }
    }
    public var spotifyURI: String? {
        switch provider {
        case  .spotify: return url
        default:        return nil
        }
    }
    public var youtubeVideoID: String? {
        switch provider {
        case .youTube: return identifier
        default:       return nil
        }
    }
    public var thumbnailURL: URL? {
        return thumbnailUrl ?? artworkUrl
    }
    public var artworkURL: URL? {
        switch self.provider {
        case .appleMusic:
            return artworkUrl ?? thumbnailUrl
        case .spotify:
            return artworkUrl ?? thumbnailUrl
        case .youTube:
            let url = youtubeVideo?.largeThumbnailURL ?? youtubeVideo?.mediumThumbnailURL ?? youtubeVideo?.smallThumbnailURL
            return url ?? thumbnailUrl
        case .soundCloud:
            guard let sc = soundcloudTrack else { return thumbnailUrl }
            return sc.artworkURL ?? thumbnailUrl
        default:
            return artworkUrl ?? thumbnailUrl
        }
    }

    public var isVideo: Bool {
        switch provider {
        case .youTube: return Track.youTubeVideoQuality != YouTubeVideoQuality.audioOnly
        case .custom, .raw:
            return (self.audioUrl?.pathExtension.lowercased()).flatMap { Track.isExtVideo(ext: $0) } ?? false
        default:       return false
        }
    }

    public var likable: Bool { return !id.isEmpty }

    public fileprivate(set) var status: Status

    public internal(set) var youtubeVideo:    YouTubeVideo?
    public internal(set) var soundcloudTrack: SoundCloudKit.Track?

    public var subtitle: String? {
        return artist
    }

    public var artist: String? {
        return ownerName ?? ownerId
    }

    public var hashValue: Int {
        return "\(provider):\(identifier)".hashValue
    }

    public class func collection(_ response: HTTPURLResponse, representation: Any) -> [Track]? {
        let json = JSON(representation)
        return json.arrayValue.map({ Track(json: $0) })
    }
    
    required public convenience init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    public init(id: String, provider: Provider, url: String, identifier: String,
                title: String? = nil, duration: TimeInterval = 0,
                thumbnailUrl: URL? = nil, artworkUrl: URL? = nil, audioUrl: URL? = nil,
                ownerId: String? = nil, ownerName: String? = nil, status: Status = .init,
                expiresAt: Int64 = Int64.max, publishedAt: Int64 = 0, createdAt: Int64 = 0, updatedAt: Int64 = 0, state: EnclosureState = .alive,
                isLiked: Bool? = nil, isSaved: Bool? = nil, isPlayed: Bool? = nil) {
        self.id           = id
        self.provider     = provider
        self.identifier   = identifier
        self.url          = url
        self.title        = title
        self.thumbnailUrl = thumbnailUrl
        self.artworkUrl   = artworkUrl
        self.audioUrl     = audioUrl
        self.duration     = duration
        self.ownerId      = ownerId
        self.ownerName    = ownerName
        self.status       = .init
        self.expiresAt    = Int64.max
        self.publishedAt  = publishedAt
        self.createdAt    = createdAt
        self.updatedAt    = updatedAt
        self.state        = state
        self.isLiked      = isLiked
        self.isSaved      = isSaved
        self.isPlayed     = isPlayed
    }

    public init(json: JSON) {
        id           = json["id"].stringValue
        provider     = Provider(rawValue: json["provider"].stringValue) ?? .raw
        title        = json["title"].string
        url          = json["url"].stringValue
        identifier   = json["identifier"].stringValue
        duration     = json["duration"].doubleValue
        thumbnailUrl = json["thumbnail_url"].string.flatMap { URL(string: $0) }
        artworkUrl   = json["artwork_url"].string.flatMap { URL(string: $0) }
        audioUrl     = json["audio_url"].string.flatMap { URL(string: $0) }
        status       = .init
        likers       = []
        entries      = []
        expiresAt    = Int64.max
        // prefer to cache
        likesCount   = json["likes_count"].int64
        likers       = json["likers"].array?.map  { Profile(json: $0) }
        savedCount   = json["saved_count"].int64
        playCount    = json["play_count"].int64
        entriesCount = json["entries_count"].int64
        entries      = json["entries"].array?.map { Entry(json: $0) }
        ownerId      = json["owner_id"].string
        ownerName    = json["owner_name"].string
        publishedAt  = json["published_at"].string.flatMap { $0.dateFromISO8601?.timestamp } ?? 0
        createdAt    = json["updated_at"].string.flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        updatedAt    = json["created_at"].string.flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        state        = json["state"].string.flatMap { EnclosureState(rawValue: $0) } ?? EnclosureState.alive
        isLiked      = json["is_liked"].bool
        isSaved      = json["is_saved"].bool
        isPlayed     = json["is_played"].bool
    }

    public init(store: TrackStore) {
        id           = store.id
        provider     = Provider(rawValue: store.providerRaw) ?? .raw
        title        = store.title
        url          = store.url
        identifier   = store.identifier
        duration     = TimeInterval(store.duration)
        status       = .init
        likesCount   = store.likesCount
        likers       = realize(store.likers).map  { Profile(store: $0) }
        playCount    = nil
        entries      = realize(store.entries).map { Entry(store: $0) }
        entriesCount = store.entriesCount
        expiresAt    = store.expiresAt
        if let u = URL(string: store.thumbnailUrl), !store.thumbnailUrl.isEmpty {
            thumbnailUrl = u
        }
        artworkUrl   = nil
        if let u = URL(string: store.streamUrl), !store.streamUrl.isEmpty {
            audioUrl = u
        }
        publishedAt  = 0
        createdAt    = 0
        updatedAt    = 0
        state        = EnclosureState.alive
        isLiked      = nil
        isSaved      = nil
        isPlayed     = nil
    }

    public init?(urlString: String) {
        var dic      = Track.parseURI(uri: urlString)
        if dic["type"] != "tracks" {
            return nil
        }
        id           = dic["id"].flatMap { $0 } ?? ""
        provider     = dic["provider"].flatMap { Provider(rawValue: $0) } ?? Provider.raw
        identifier   = dic["identifier"] ?? ""
        url          = dic["url"] ?? urlString
        title        = dic["title"]
        duration     = dic["duration"].flatMap { Int64($0) }.flatMap { TimeInterval( $0 / 1000) } ?? 0
        thumbnailUrl = dic["thumbnail_url"].flatMap { URL(string: $0) }
        artworkUrl   = dic["artwork_url"].flatMap { URL(string: $0) }
        audioUrl     = dic["audio_url"].flatMap { URL(string: $0) }
        publishedAt  = dic["published_at"].flatMap { $0.dateFromISO8601?.timestamp } ?? 0
        createdAt    = dic["updated_at"].flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        updatedAt    = dic["created_at"].flatMap { $0.dateFromISO8601?.timestamp }   ?? 0
        state        = dic["state"].flatMap { EnclosureState(rawValue: $0) } ?? EnclosureState.alive
        ownerName    = dic["owner_name"]
        ownerId      = dic["owner_id"]
        likesCount   = dic["likes_count"].flatMap { Int64($0) }
        playCount    = dic["play_count"].flatMap { Int64($0) }
        entriesCount = dic["entries_count"].flatMap { Int64($0) }
        status       = .init
        expiresAt    = Int64.max

        isLiked      = dic["is_liked"].flatMap { $0 == "true" }
        isSaved      = dic["is_saved"].flatMap { $0 == "true" }
        isPlayed     = dic["is_played"].flatMap { $0 == "true" }
    }

    public func updateMarkProperties(item: Track) {
        isLiked    = item.isLiked
        isSaved    = item.isSaved
        likesCount = item.likesCount
        savedCount = item.savedCount
        playCount  = item.playCount
    }

    public var permalinkUrl: URL? {
        switch self.provider {
        case .youTube:
            return URL(string: "https://www.youtube.com/watch?v=\(self.identifier)")
        case .soundCloud:
            return URL(string: url)
        case .appleMusic:
            return URL(string: url)
        case .spotify:
            let arr  = url.components(separatedBy: ":")
            return URL(string: "http://open.spotify.com/\(arr[1])/\(arr[2])")
        default:
            return URL(string: url)
        }
    }

    public func fetchPropertiesFromProviderIfNeed() -> SignalProducer<Track, NSError> {
        switch provider {
        case .youTube:
            if Track.canPlayYouTubeWithAVPlayer && (audioUrl == nil || expiresAt < Date().timestamp) {
                status       = .init
                audioUrl     = nil
                youtubeVideo = nil
                expiresAt    = 0
                return fetchPropertiesFromProvider(false)
            } else {
                status = .available
                return SignalProducer<Track, NSError>(value: self)
            }
        default:
            return fetchPropertiesFromProvider(false)
        }
    }

    public func create() -> Bool {
        return TrackStore.create(self)
    }

    public func save() -> Bool {
        return TrackStore.save(self)
    }

    public func updateProperties(_ track: SoundCloudKit.Track) {
        soundcloudTrack = track
        title           = track.title
        duration        = TimeInterval(track.duration / 1000)
        audioUrl        = URL(string: track.streamUrl + "?client_id=" + APIClient.shared.clientId)
        ownerId         = String(soundcloudTrack?.user.id ?? 0)
        ownerName       = soundcloudTrack?.user.username
        status          = .available

        if let url = track.thumbnailURL {
            thumbnailUrl = url
        }
    }
    
    public func updateProperties(_ video: YouTubeVideo) {
        youtubeVideo = video
        title        = video.title
        duration     = video.duration
        if thumbnailUrl == nil {
            thumbnailUrl = video.mediumThumbnailURL ?? video.smallThumbnailURL
        }
        audioUrl     = youtubeVideo?.streamURLs[Track.youTubeVideoQuality.key] // for cache
        expiresAt    = youtubeVideo?.expirationDate?.timestamp ?? Int64.max
        status       = .available
    }

    public func updateProviderProperties(_ store: TrackStore) {
        title       = store.title
        duration    = TimeInterval(store.duration)
        if let url = URL(string: store.thumbnailUrl), !store.thumbnailUrl.isEmpty {
            thumbnailUrl = url
        }
        if let url = URL(string: store.streamUrl), !store.streamUrl.isEmpty, audioUrl == nil {
            audioUrl = url
        }
        ownerName = store.artist
        switch provider {
        case .youTube:
            expiresAt = store.expiresAt
        case .soundCloud:
            expiresAt = Int64.max
        default:
            expiresAt = Int64.max
        }
    }

    public func updateProperties(_ store: TrackStore) {
        url          = store.url
        likesCount   = store.likesCount
        entriesCount = store.entriesCount
        likers       = realize(store.likers).map  { Profile(store: $0) }
        entries      = realize(store.entries).map { Entry(store: $0) }
    }

    internal func toStoreObject() -> TrackStore {
        let store            = TrackStore()
        store.id             = id
        store.url            = url
        store.providerRaw    = provider.rawValue
        store.identifier     = identifier
        store.title          = title ?? ""
        store.thumbnailUrl   = thumbnailUrl?.absoluteString ?? ""
        store.streamUrl      = audioUrl?.absoluteString ?? ""
        store.duration       = Int(duration)
        store.likesCount     = likesCount ?? 0
        store.entriesCount   = entriesCount ?? 0
        // entries and likers are not neccesary, depends on the store
        store.expiresAt      = expiresAt
        store.artist         = ownerName ?? ownerId ?? ""
        return store
    }

    public func toJSON() -> [String: Any?] {
        return [
            "id":            id,
            "provider":      provider.rawValue,
            "identifier":    identifier,
            "url":           url,
            "entries":       entries?.map { $0.toJSON() },
            "entries_count":  entriesCount,
            "title":         title,
            "thumbnail_url": thumbnailURL?.absoluteString,
            "artwork_url":   artworkURL?.absoluteString,
            "audio_url":     audioUrl?.absoluteString,
            "duration":      duration,
            "likes_count":   likesCount,
//            "likers": likers,
            "saved_count":   savedCount,
            "play_count":    playCount,
            "expires_at":    expiresAt,
            "owner_id":       ownerId,
            "owner_name":     ownerName,
            "published_at":  publishedAt,
            "updated_at":    updatedAt,
            "created_at":    createdAt,
            "state":         state.rawValue,
        ]
    }

    #if os(iOS)
    public func open() {
        if let url = permalinkUrl {
            UIApplication.shared.openURL(url)
        }
    }
    #endif

    public func fetchDetail() -> SignalProducer<Track, NSError> {
        if CloudAPIClient.includesTrack {
            return fetchTrack().combineLatest(with: fetchPropertiesFromProviderIfNeed()).map {_,_ in
                return self
            }
        } else {
            return fetchPropertiesFromProvider(false)
        }
    }

    public func invalidate() -> Track {
        status = .dirty
        return self
    }
    
    fileprivate func fetchTrack() -> SignalProducer<Track, NSError> {
        if status == .init || status == .cache || status == .dirty {
            return fetch().map { (track: Track) -> Track in
                self.likesCount   = track.likesCount
                self.entriesCount = track.entriesCount
                self.entries      = track.entries
                return self
            }
        } else {
            return SignalProducer<Track, NSError>(value: self)
        }
    }

    fileprivate func fetchPropertiesFromProvider(_ errorOnFailure: Bool) -> SignalProducer<Track, NSError> {
        return SignalProducer<Track, NSError> { (observer, disposable) in
            if self.status == .available || self.status == .loading {
                observer.send(value: self)
                observer.sendCompleted()
                return
            }
            self.status = .loading
            switch self.provider {
            case .appleMusic:
                self.status = .available
                observer.send(value: self)
                observer.sendCompleted()
            case .spotify:
                self.status = .available
                observer.send(value: self)
                observer.sendCompleted()
            case .youTube:
                guard let apiClient = Track.youtubeAPIClient else {
                    self.status = .available
                    observer.send(value: self)
                    observer.sendCompleted()
                    return
                }
                let disp = apiClient.fetchVideo(self.identifier).on(
                    failed: { error in
                        if self.status != .available { self.status = .unavailable }
                        observer.send(value: self)
                        observer.sendCompleted()
                    }, interrupted: {
                        if self.status != .available { self.status = .init }
                        observer.send(value: self)
                        observer.sendCompleted()
                    }, value: { video in
                        self.updateProperties(video)
                        observer.send(value: self)
                        observer.sendCompleted()
                    }).start()
                disposable.observeEnded {
                    disp.dispose()
                }
            case .soundCloud:
                self.status    = .available
                observer.send(value: self)
                observer.sendCompleted()
            case .custom:
                self.status    = .available
                observer.send(value: self)
                observer.sendCompleted()
            case .raw:
                self.status    = .available
                observer.send(value: self)
                observer.sendCompleted()
            }
        }
    }

    public class func findBy(url: String) -> Track? {
        if let store = TrackStore.findBy(url: url) {
            return Track(store: store)
        }
        return nil
    }

    public class func findBy(id: String) -> Track? {
        if let store = TrackStore.findBy(id: id) {
            return Track(store: store)
        }
        return nil
    }

    public class func findAll() -> [Track] {
        return TrackStore.findAll().map({ Track(store: $0) })
    }

    public class func removeAll() {
        return TrackStore.removeAll()
    }
    open func sendToSharedPipe() {
        TrackStreamRepository.sharedPipe.1.send(value: self)
    }
    #if os(iOS)
    fileprivate func loadImage(imageURL: URL?, completeHandler: @escaping (UIImage?) -> Void) {
        if let url = imageURL {
            SDWebImageManager.shared().loadImage(with: url,
                                              options: .highPriority,
                                             progress: {receivedSize, expectedSize, url in }) { (image, data, error, cacheType, finished, url) -> Void in
                                                completeHandler(image)
            }
        } else {
            completeHandler(nil)
        }
    }
    public func loadThumbnailImage(completeHandler: @escaping (UIImage?) -> Void) {
        if let image = mediaItem?.artwork?.image(at: Track.thumbnailImageSize) {
            completeHandler(image)
            return
        }
        loadImage(imageURL: thumbnailURL, completeHandler: completeHandler)
    }
    public func loadArtworkImage(completeHandler: @escaping (UIImage?) -> Void) {
        if let image = mediaItem?.artwork?.image(at: Track.artworkImageSize) {
            completeHandler(image)
            return
        }
        loadImage(imageURL: artworkURL, completeHandler: completeHandler)
    }
    #endif
}

public func ==(lhs: Track, rhs: Track) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
