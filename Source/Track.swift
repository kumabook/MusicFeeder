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
    case YouTube    = "YouTube"
    case SoundCloud = "SoundCloud"
    case Raw        = "Raw"
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

final public class Track: PlayerKit.Track, Equatable, Hashable, ResponseObjectSerializable, ResponseCollectionSerializable {
    fileprivate static let userDefaults = UserDefaults.standard
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
    public fileprivate(set) var title:        String?
    public fileprivate(set) var thumbnailUrl: URL?
    public fileprivate(set) var duration:     TimeInterval
    public fileprivate(set) var likesCount:   Int64?
    public fileprivate(set) var likers:       [Profile]?
    public fileprivate(set) var expiresAt:    Int64
    public fileprivate(set) var artist:       String?
    public var streamURL: URL? {
        switch provider {
        case .YouTube:
            return youtubeVideo?.streamURLs[Track.youTubeVideoQuality.key] ?? streamUrl
        case .SoundCloud:
            return soundcloudTrack.map { URL(string: $0.streamUrl + "?client_id=" + APIClient.clientId) } ?? streamUrl
        case .Raw:
            return self.identifier.toURL()
        }
    }
    public var thumbnailURL: URL? {
        return thumbnailUrl
    }
    public var artworkURL: URL? {
        switch self.provider {
        case .YouTube:
            let url = youtubeVideo?.largeThumbnailURL ?? youtubeVideo?.mediumThumbnailURL ?? youtubeVideo?.smallThumbnailURL
            return url ?? thumbnailUrl
        case .SoundCloud:
            guard let sc = soundcloudTrack else { return thumbnailUrl }
            return sc.artworkURL ?? thumbnailUrl
        default:
            break
        }
        return nil
    }

    public var isVideo: Bool {
        return provider == Provider.YouTube && Track.youTubeVideoQuality != YouTubeVideoQuality.audioOnly
    }

    public var likable: Bool { return !id.isEmpty }

    public fileprivate(set) var status: Status

    public fileprivate(set) var streamUrl:  URL?
    public fileprivate(set) var youtubeVideo:    XCDYouTubeVideo?
    public fileprivate(set) var soundcloudTrack: SoundCloudKit.Track?

    public var subtitle: String? {
        switch provider {
        case .YouTube:
            return nil
        case .SoundCloud:
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

    public init(id: String, provider: Provider, url: String, identifier: String, title: String?) {
        self.id         = id
        self.provider   = provider
        self.url        = url
        self.identifier = identifier
        self.title      = title
        self.duration   = 0 as TimeInterval
        self.status     = .init
        self.expiresAt  = 0
    }

    public init(json: JSON) {
        id          = json["id"].stringValue
        provider    = Provider(rawValue: json["provider"].stringValue)!
        title       = nil
        url         = json["url"].stringValue
        identifier  = json["identifier"].stringValue
        likesCount  = 0
        duration    = 0 as TimeInterval
        status      = .init
        likers      = []
        entries     = []
        expiresAt   = 0
        // prefer to cache
        likesCount  = json["likesCount"].int64Value
        likers      = json["likers"].array?.map  { Profile(json: $0) }
        entries     = json["entries"].array?.map { Entry(json: $0) }
    }

    public init(store: TrackStore) {
        id          = store.id
        provider    = Provider(rawValue: store.providerRaw)!
        title       = store.title
        url         = store.url
        identifier  = store.identifier
        duration    = TimeInterval(store.duration)
        status      = .init
        likesCount = store.likesCount
        likers     = realize(store.likers).map  { Profile(store: $0 as! ProfileStore) }
        entries    = realize(store.entries).map { Entry(store: $0 as! EntryStore) }
        expiresAt  = store.expiresAt
        if let url = URL(string: store.thumbnailUrl), !store.thumbnailUrl.isEmpty {
            thumbnailUrl = url
        }
    }

    public init(urlString: String) {
        let components: URLComponents? = URLComponents(string: urlString)
        var dic: [String:String] = [:]
        components?.queryItems?.forEach {
            dic[$0.name] = $0.value
        }
        id          = dic["id"].flatMap { $0 } ?? ""
        provider    = dic["provider"].flatMap { Provider(rawValue: $0) } ?? Provider.YouTube
        title       = dic["title"]
        url         = urlString
        identifier  = dic["identifier"] ?? ""
        duration    = dic["duration"].flatMap { Int64($0) }.flatMap { TimeInterval( $0 / 1000) } ?? 0
        likesCount  = dic["likesCount"].flatMap { Int64($0) }
        status      = .init
        expiresAt   = 0
    }

    public func fetchPropertiesFromProviderIfNeed() -> SignalProducer<Track, NSError> {
        if streamUrl == nil || expiresAt < Date().timestamp {
            status       = .init
            streamUrl    = nil
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
        streamUrl       = URL(string: track.streamUrl + "?client_id=" + APIClient.clientId)
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
        streamUrl    = youtubeVideo?.streamURLs[Track.youTubeVideoQuality.key] // for cache
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
            streamUrl = url
        }
        artist = store.artist
        switch provider {
        case .YouTube:
            expiresAt = store.expiresAt
        case .SoundCloud:
            expiresAt = Int64.max
        default:
            expiresAt = Int64.max
        }
    }

    public func updateProperties(_ store: TrackStore) {
        url        = store.url
        likesCount = store.likesCount
        likers     = realize(store.likers).map  { Profile(store: $0 as! ProfileStore) }
        entries    = realize(store.entries).map { Entry(store: $0 as! EntryStore) }
    }

    internal func toStoreObject() -> TrackStore {
        let store            = TrackStore()
        store.id             = id
        store.url            = url
        store.providerRaw    = provider.rawValue
        store.identifier     = identifier
        store.title          = title ?? ""
        store.thumbnailUrl   = thumbnailUrl?.absoluteString ?? ""
        store.streamUrl      = streamUrl?.absoluteString ?? ""
        store.duration       = Int(duration)
        store.likesCount     = likesCount ?? 0
        // entries and likers are not neccesary, depends on the store
        store.expiresAt      = expiresAt
        store.artist         = artist ?? ""
        return store
    }

    public func markAsLiked() -> ReactiveSwift.SignalProducer<Track, NSError> {
        return CloudAPIClient.sharedInstance.markTracksAsLiked([self]).flatMap(.concat) {
            self.invalidate().fetchDetail()
        }
    }
    
    public func markAsUnliked() -> ReactiveSwift.SignalProducer<Track, NSError> {
        return CloudAPIClient.sharedInstance.markTracksAsUnliked([self]).flatMap(.concat) {
            self.invalidate().fetchDetail()
        }
    }

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
            return CloudAPIClient.sharedInstance.fetchTrack(id).map {
                self.likesCount = $0.likesCount
                self.entries    = $0.entries
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
            case .YouTube:
                let disp = XCDYouTubeClient.default().fetchVideo(self.identifier).on(
                    value: { video in
                        self.updateProperties(video)
                        observer.send(value: self)
                        observer.sendCompleted()
                    }, failed: { error in
                        if self.status != .available { self.status = .unavailable }
                        observer.send(value: self)
                        observer.sendCompleted()
                    }, interrupted: {
                        if self.status != .available { self.status = .init }
                        observer.send(value: self)
                        observer.sendCompleted()
                    }).start()
                disposable.add {
                    disp.dispose()
                }
                return
            case .SoundCloud:
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
            case .Raw:
                self.streamUrl = self.identifier.toURL()
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
