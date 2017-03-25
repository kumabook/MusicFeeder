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
import XCDYouTubeKit
import PlayerKit
import Breit
import SoundCloudKit
import Alamofire
import FeedlyKit

public enum Provider: String {
    case appleMusic = "AppleMusic"
    case spotify    = "Spotify"
    case youTube    = "YouTube"
    case soundCloud = "SoundCloud"
    case raw        = "Raw"
}

public enum YouTubeVideoQuality: Int64 {
    case audioOnly = 140
    case small240  = 36
    case medium360 = 18
    case hd720     = 22
    public var label: String {
        switch self {
        case .audioOnly: return  "Audio only".localize()
        case .small240:  return  "Small 240".localize()
        case .medium360: return  "Medium 360".localize()
        case .hd720:     return  "HD 720".localize()
        }
    }
    public var key: AnyHashable {
        return NSNumber(value: rawValue)
    }
    #if os(iOS)
    public static func buildAlertActions(_ handler: @escaping () -> ()) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        actions.append(UIAlertAction(title: YouTubeVideoQuality.audioOnly.label,
                                     style: .default,
                                  handler: { action in Track.youTubeVideoQuality = .audioOnly; handler() }))

        actions.append(UIAlertAction(title: YouTubeVideoQuality.small240.label,
                                     style: .default,
                                   handler: { action in Track.youTubeVideoQuality = .small240; handler() }))
        actions.append(UIAlertAction(title: YouTubeVideoQuality.medium360.label,
                                     style: .default,
                                   handler: { action in Track.youTubeVideoQuality = .medium360; handler() }))
        actions.append(UIAlertAction(title: YouTubeVideoQuality.hd720.label,
                                     style: .default,
                                   handler: { action in  Track.youTubeVideoQuality = .hd720; handler() }))
        return actions
    }
    #endif
}

final public class Track: PlayerKit.Track, Equatable, Hashable, Enclosure {
    public static var resourceName: String = "tracks"
    public static var idListKey:    String = "trackIds"
    fileprivate static let userDefaults = UserDefaults.standard
    public static var appleMusicCurrentCountry: String? = nil
    public static var isSpotifyPremiumUser: Bool = false
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
    public fileprivate(set) var playCount:    Int64?
    public fileprivate(set) var expiresAt:    Int64
    public fileprivate(set) var artist:       String?
    public fileprivate(set) var publishedAt:  Int64
    public fileprivate(set) var updatedAt:    Int64
    public fileprivate(set) var createdAt:    Int64
    public fileprivate(set) var state:        EnclosureState
    public                  var isLiked:      Bool?
    public                  var isSaved:      Bool?
    public                  var isPlayed:     Bool?
    public var playerType: PlayerType {
        switch provider {
        case .appleMusic:
            if let c = country, c == Track.appleMusicCurrentCountry {
                return .appleMusic
            }
            return .normal
        case .spotify:    return Track.isSpotifyPremiumUser ? .spotify : .normal
        default:          return .normal
        }
    }
    public var isValid: Bool {
        switch provider {
        case .appleMusic:
            return country == Track.appleMusicCurrentCountry || audioUrl != nil
        case .spotify:
            return spotifyURI != nil
        default:
            return streamURL != nil
        }
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
            return soundcloudTrack.map { URL(string: $0.streamUrl + "?client_id=" + APIClient.clientId) } ??
                audioUrl.map { URL(string: $0.absoluteString + "?client_id=" + APIClient.clientId) } ?? nil
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
    public var thumbnailURL: URL? {
        return thumbnailUrl
    }
    public var artworkURL: URL? {
        switch self.provider {
        case .appleMusic:
            return thumbnailUrl
        case .spotify:
            return thumbnailUrl
        case .youTube:
            let url = youtubeVideo?.largeThumbnailURL ?? youtubeVideo?.mediumThumbnailURL ?? youtubeVideo?.smallThumbnailURL
            return url ?? thumbnailUrl
        case .soundCloud:
            guard let sc = soundcloudTrack else { return thumbnailUrl }
            return sc.artworkURL ?? thumbnailUrl
        default:
            break
        }
        return nil
    }

    public var isVideo: Bool {
        return provider == Provider.youTube && Track.youTubeVideoQuality != YouTubeVideoQuality.audioOnly
    }

    public var likable: Bool { return !id.isEmpty }

    public fileprivate(set) var status: Status

    public fileprivate(set) var youtubeVideo:    XCDYouTubeVideo?
    public fileprivate(set) var soundcloudTrack: SoundCloudKit.Track?

    public var subtitle: String? {
        switch provider {
        case .appleMusic:
            return artist
        case .spotify:
            return artist
        case .youTube:
            return artist
        case .soundCloud:
            return soundcloudTrack?.user.username
        default:
            return nil
        }
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
                artist: String? = nil, status: Status = .init,
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
        self.artist       = artist
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
        provider     = Provider(rawValue: json["provider"].stringValue)!
        title        = json["title"].string
        url          = json["url"].stringValue
        identifier   = json["identifier"].stringValue
        likesCount   = nil
        playCount    = nil
        duration     = json["duration"].doubleValue
        thumbnailUrl = json["thumbnail_url"].string.flatMap { URL(string: $0) }
        artworkUrl   = json["artwork_url"].string.flatMap { URL(string: $0) }
        audioUrl     = json["audio_url"].string.flatMap { URL(string: $0) }
        status       = .init
        likers       = []
        entries      = []
        expiresAt    = Int64.max
        // prefer to cache
        likesCount   = json["likes_count"].int64Value
        likers       = json["likers"].array?.map  { Profile(json: $0) }
        playCount    = json["play_count"].int64Value
        entriesCount = json["entries_count"].int64Value
        entries      = json["entries"].array?.map { Entry(json: $0) }
        artist       = json["owner_name"].string
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
        provider     = Provider(rawValue: store.providerRaw)!
        title        = store.title
        url          = store.url
        identifier   = store.identifier
        duration     = TimeInterval(store.duration)
        status       = .init
        likesCount   = store.likesCount
        likers       = realize(store.likers).map  { Profile(store: $0 as! ProfileStore) }
        entries      = realize(store.entries).map { Entry(store: $0 as! EntryStore) }
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
        isLiked      = false
        isSaved      = false
        isPlayed     = false
    }

    public init?(urlString: String) {
        var dic      = Track.parseURI(uri: urlString)
        if dic["type"] != "tracks" {
            return nil
        }
        id           = dic["id"].flatMap { $0 } ?? ""
        provider     = dic["provider"].flatMap { Provider(rawValue: $0) } ?? Provider.youTube
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
        artist       = dic["owner_name"] ?? dic["owner_id"]

        likesCount   = dic["likes_count"].flatMap { Int64($0) }
        playCount    = dic["play_count"].flatMap { Int64($0) }
        entriesCount = dic["entries_count"].flatMap { Int64($0) }
        status       = .init
        expiresAt    = Int64.max

        isLiked      = dic["is_liked"].flatMap { $0 == "true" }
        isSaved      = dic["is_saved"].flatMap { $0 == "true" }
        isPlayed     = dic["is_played"].flatMap { $0 == "true" }
    }

    public func fetchPropertiesFromProviderIfNeed() -> SignalProducer<Track, NSError> {
        if audioUrl == nil || expiresAt < Date().timestamp {
            status       = .init
            audioUrl     = nil
            youtubeVideo = nil
            expiresAt    = 0
            return fetchPropertiesFromProvider(false)
        } else {
            status = .available
            return SignalProducer<Track, NSError>(value: self)
        }
    }

    public func create() -> Bool {
        return TrackStore.create(self)
    }

    public func save() -> Bool {
        return TrackStore.save(self)
    }

    fileprivate func cacheProperties() {
        QueueScheduler().schedule {
            TrackRepository.sharedInstance.cacheTrack(self)
        }
    }

    public func loadPropertiesFromCache(_ providerOnly: Bool = false) {
        if let store = TrackRepository.sharedInstance.getCacheTrackStore(id) {
            if !providerOnly {
                self.updateProperties(store)
            }
            self.updateProviderProperties(store)
            status = .cache
        }
    }

    public func updateProperties(_ track: SoundCloudKit.Track) {
        soundcloudTrack = track
        title           = track.title
        duration        = TimeInterval(track.duration / 1000)
        audioUrl        = URL(string: track.streamUrl + "?client_id=" + APIClient.clientId)
        artist          = soundcloudTrack?.user.username
        status          = .available

        if let url = track.thumbnailURL {
            thumbnailUrl = url
        }
    }
    
    public func updateProperties(_ video: XCDYouTubeVideo) {
        youtubeVideo = video
        title        = video.title
        duration     = video.duration
        thumbnailUrl = video.mediumThumbnailURL
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
        if let url = URL(string: store.streamUrl), !store.streamUrl.isEmpty {
            audioUrl = url
        }
        artist = store.artist
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
        likers       = realize(store.likers).map  { Profile(store: $0 as! ProfileStore) }
        entries      = realize(store.entries).map { Entry(store: $0 as! EntryStore) }
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
        store.artist         = artist ?? ""
        return store
    }

    #if os(iOS)
    public func open() {
        if let url = URL(string: url) {
            UIApplication.shared.openURL(url)
        }
    }
    #endif

    public func fetchDetail() -> SignalProducer<Track, NSError> {
        if CloudAPIClient.includesTrack {
            return fetchTrack().combineLatest(with: fetchPropertiesFromProviderIfNeed()).map {_,_ in
                self.cacheProperties()
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
                let disp = XCDYouTubeClient.default().fetchVideo(self.identifier).on(
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
                disposable.add {
                    disp.dispose()
                }
                return
            case .soundCloud:
                typealias R = SoundCloudKit.APIClient.Router
                SoundCloudKit.APIClient.sharedInstance.fetchItem(R.track(self.identifier)) { (req:
                    URLRequest?, res: HTTPURLResponse?, result: Alamofire.Result<SoundCloudKit.Track>) -> Void in
                    if let track = result.value {
                        self.updateProperties(track)
                        observer.send(value: self)
                        observer.sendCompleted()
                    } else {
                        self.status = .unavailable
                        observer.send(value: self)
                        observer.sendCompleted()
                    }
                }
                return
            case .raw:
                self.audioUrl = self.identifier.toURL()
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
}

public func ==(lhs: Track, rhs: Track) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
