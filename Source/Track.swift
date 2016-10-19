//
//  Track.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/28/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import SwiftyJSON
import ReactiveCocoa
import Result
import XCDYouTubeKit
import UIKit
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

public enum YouTubeVideoQuality: UInt {
    case AudioOnly = 140
    case Small240  = 36
    case Medium360 = 18
    case HD720     = 22
    public var label: String {
        switch self {
        case .AudioOnly: return  "Audio only".localize()
        case .Small240:  return  "Small 240".localize()
        case .Medium360: return  "Medium 360".localize()
        case .HD720:     return  "HD 720".localize()
        }
    }
    public static func buildAlertActions(handler: () -> ()) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        actions.append(UIAlertAction(title: YouTubeVideoQuality.AudioOnly.label,
                                     style: .Default,
                                  handler: { action in Track.youTubeVideoQuality = .AudioOnly; handler() }))

        actions.append(UIAlertAction(title: YouTubeVideoQuality.Small240.label,
                                     style: .Default,
                                   handler: { action in Track.youTubeVideoQuality = .Small240; handler() }))
        actions.append(UIAlertAction(title: YouTubeVideoQuality.Medium360.label,
                                     style: .Default,
                                   handler: { action in Track.youTubeVideoQuality = .Medium360; handler() }))
        actions.append(UIAlertAction(title: YouTubeVideoQuality.HD720.label,
                                     style: .Default,
                                   handler: { action in  Track.youTubeVideoQuality = .HD720; handler() }))
        return actions
    }
}

final public class Track: PlayerKit.Track, Equatable, Hashable, ResponseObjectSerializable, ResponseCollectionSerializable {
    private static let userDefaults = NSUserDefaults.standardUserDefaults()
    public static var youTubeVideoQuality: YouTubeVideoQuality {
        get {
            if let quality = YouTubeVideoQuality(rawValue: UInt(userDefaults.integerForKey("youtube_video_quality"))) {
                return quality
            } else {
                return YouTubeVideoQuality.Medium360
            }
        }
        set(quality) {
            userDefaults.setInteger(Int(quality.rawValue), forKey: "youtube_video_quality")
        }
    }

    public enum Status {
        case Init
        case Loading
        case Available
        case Unavailable
    }
    public private(set) var id:           String
    public private(set) var provider:     Provider
    public private(set) var identifier:   String

    public private(set) var url:          String
    public private(set) var entries:      [Entry]?
    public private(set) var title:        String?
    public private(set) var thumbnailUrl: NSURL?
    public private(set) var duration:     NSTimeInterval
    public private(set) var likesCount:   Int64?
    public private(set) var likers:       [Profile]?
    public var artworkUrl: NSURL? {
        switch self.provider {
        case .YouTube:
            return youtubeVideo?.largeThumbnailURL ?? youtubeVideo?.mediumThumbnailURL ?? youtubeVideo?.smallThumbnailURL
        case .SoundCloud:
            guard let sc = soundcloudTrack else { return nil }
            return sc.artworkURL
        default:
            break
        }
        return nil
    }


    public var isVideo: Bool {
        return provider == Provider.YouTube && Track.youTubeVideoQuality != YouTubeVideoQuality.AudioOnly
    }

    public var likable: Bool { return !id.isEmpty }

    public private(set) var status: Status

    private var _streamUrl:  NSURL?
    public private(set) var youtubeVideo:    XCDYouTubeVideo?
    public private(set) var soundcloudTrack: SoundCloudKit.Track?

    public var streamUrl: NSURL? {
        if let video = youtubeVideo {
            return video.streamURLs[Track.youTubeVideoQuality.rawValue]
        } else if let url = _streamUrl {
            return  url
        }
        return nil
    }

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

    public class func collection(response response: NSHTTPURLResponse, representation: AnyObject) -> [Track]? {
        let json = JSON(representation)
        return json.arrayValue.map({ Track(json: $0) })
    }
    
    required public convenience init?(response: NSHTTPURLResponse, representation: AnyObject) {
        let json = JSON(representation)
        self.init(json: json)
    }

    public init(id: String, provider: Provider, url: String, identifier: String, title: String?) {
        self.id         = id
        self.provider   = provider
        self.url        = url
        self.identifier = identifier
        self.title      = title
        self.duration   = 0 as NSTimeInterval
        self.status     = .Init
        loadPropertiesFromCache()
    }

    public init(json: JSON) {
        id          = json["id"].stringValue
        provider    = Provider(rawValue: json["provider"].stringValue)!
        title       = nil
        url         = json["url"].stringValue
        identifier  = json["identifier"].stringValue
        likesCount  = json["likesCount"].int64Value
        duration    = 0 as NSTimeInterval
        status      = .Init
        likers      = json["likers"].array?.map  { Profile(json: $0) }
        entries     = json["entries"].array?.map { Entry(json: $0) }
    }

    public init(store: TrackStore) {
        id          = store.id
        provider    = Provider(rawValue: store.providerRaw)!
        title       = store.title
        url         = store.url
        identifier  = store.identifier
        duration    = NSTimeInterval(store.duration)
        status      = .Init
        if let url = NSURL(string: store.thumbnailUrl) where !store.thumbnailUrl.isEmpty {
            thumbnailUrl = url
        }
        likesCount = store.likesCount
        likers     = store.likers.map  { Profile(store: $0 as! ProfileStore) }
        entries    = store.entries.map { Entry(store: $0 as! EntryStore) }
        loadPropertiesFromCache()
    }

    public init(urlString: String) {
        let components: NSURLComponents? = NSURLComponents(string: urlString)
        var dic: [String:String] = [:]
        components?.queryItems?.forEach {
            dic[$0.name] = $0.value
        }
        id          = dic["id"].flatMap { $0 } ?? ""
        provider    = dic["provider"].flatMap { Provider(rawValue: $0) } ?? Provider.YouTube
        title       = dic["title"]
        url         = urlString
        identifier  = dic["identifier"] ?? ""
        duration    = dic["duration"].flatMap { Int64($0) }.flatMap { NSTimeInterval( $0 / 1000) } ?? 0
        likesCount  = dic["likesCount"].flatMap { Int64($0) }
        status      = .Init
        loadPropertiesFromCache()
    }

    public func reloadExpiredDetail() -> SignalProducer<Track, NSError> {
        var signal = SignalProducer<Track, NSError>.empty
        if let expirationDate = youtubeVideo?.expirationDate {
            if expirationDate.timestamp < NSDate().timestamp {
                status = .Init
                _streamUrl = nil
                youtubeVideo = nil
                signal = signal.concat(fetchPropertiesFromProvider(false))
            }
        }
        return signal
    }

    public func create() -> Bool {
        return TrackStore.create(self)
    }

    public func save() -> Bool {
        return TrackStore.save(self)
    }

    private func cacheProperties() {
        TrackRepository.sharedInstance.cacheTrack(self)
    }

    private func loadPropertiesFromCache() {
        if let store = TrackRepository.sharedInstance.getCacheTrackStore(id) {
            self.updateProperties(store)
        }
    }

    public func updateProperties(track: SoundCloudKit.Track) {
        soundcloudTrack = track
        title           = track.title
        duration        = NSTimeInterval(track.duration / 1000)
        _streamUrl      = NSURL(string: track.streamUrl + "?client_id=" + APIClient.clientId)
        status          = .Available

        if let url = track.thumbnailURL {
            thumbnailUrl = url
        }
    }
    
    public func updateProperties(video: XCDYouTubeVideo) {
        youtubeVideo = video
        title        = video.title
        duration     = video.duration
        thumbnailUrl = video.mediumThumbnailURL
        status       = .Available
    }

    public func updateProperties(store: TrackStore) {
        title       = store.title
        url         = store.url
        duration    = NSTimeInterval(store.duration)
        if let url = NSURL(string: store.thumbnailUrl) where !store.thumbnailUrl.isEmpty {
            thumbnailUrl = url
        }
        likesCount = store.likesCount
        likers     = store.likers.map  { Profile(store: $0 as! ProfileStore) }
        entries    = store.entries.map { Entry(store: $0 as! EntryStore) }
    }

    internal func toStoreObject() -> TrackStore {
        let store            = TrackStore()
        store.id             = id
        store.url            = url
        store.providerRaw    = provider.rawValue
        store.identifier     = identifier
        if let _title        = title                        { store.title        = _title }
        if let _thumbnailUrl = thumbnailUrl?.absoluteString { store.thumbnailUrl = _thumbnailUrl }
        if provider != .YouTube {
            if let _streamUrl = streamUrl?.absoluteString   { store.streamUrl    = _streamUrl }
        }
        store.duration       = Int(duration)
        store.likesCount     = likesCount ?? 0
        // entries and likers are not neccesary, depends on the store
        return store
    }

    public func fetchDetail() -> SignalProducer<Track, NSError> {
        if CloudAPIClient.includesTrack {
            return CloudAPIClient.sharedInstance.fetchTrack(id).combineLatestWith(fetchPropertiesFromProvider(false)).map {
                self.likesCount = $0.0.likesCount
                self.entries    = $0.0.entries
                self.cacheProperties()
                return self
            }
        } else {
            return fetchPropertiesFromProvider(false)
        }
    }

    public func fetchPropertiesFromProvider(errorOnFailure: Bool) -> SignalProducer<Track, NSError>{
        return SignalProducer<Track, NSError> { (observer, disposable) in
            if self.status == .Available || self.status == .Loading {
                observer.sendNext(self)
                observer.sendCompleted()
                return
            }
            self.status = .Loading
            switch self.provider {
            case .YouTube:
                let disp = XCDYouTubeClient.defaultClient().fetchVideo(self.identifier).on(
                    next: { video in
                        self.updateProperties(video)
                        observer.sendNext(self)
                        observer.sendCompleted()
                    }, failed: { error in
                        if self.status != .Available { self.status = .Unavailable }
                        observer.sendNext(self)
                        observer.sendCompleted()
                    }, interrupted: {
                        if self.status != .Available { self.status = .Unavailable }
                        observer.sendNext(self)
                        observer.sendCompleted()
                    }).start()
                disposable.addDisposable {
                    disp.dispose()
                }
                return
            case .SoundCloud:
                typealias R = SoundCloudKit.APIClient.Router
                SoundCloudKit.APIClient.sharedInstance.fetchItem(R.Track(self.identifier)) { (req: NSURLRequest?, res: NSHTTPURLResponse?, result: Alamofire.Result<SoundCloudKit.Track, NSError>) -> Void in
                    if let track = result.value {
                        self.updateProperties(track)
                        observer.sendNext(self)
                        observer.sendCompleted()
                    } else {
                        self.status = .Unavailable
                        observer.sendNext(self)
                        observer.sendCompleted()
                    }
                }
                return
            case .Raw:
                self._streamUrl = self.identifier.toURL()
                self.status    = .Available
                observer.sendNext(self)
                observer.sendCompleted()
            }
        }
    }

    public class func findBy(url url: String) -> Track? {
        if let store = TrackStore.findBy(url: url) {
            return Track(store: store)
        }
        return nil
    }

    public class func findBy(id id: String) -> Track? {
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
