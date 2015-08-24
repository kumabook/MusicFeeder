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
import Box
import XCDYouTubeKit
import UIKit
import PlayerKit
import Breit
import SoundCloudKit

public enum Provider: String {
    case Youtube    = "YouTube"
    case SoundCloud = "SoundCloud"
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
        default:         return  "Unknown".localize()
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

@objc public class Track: PlayerKit.Track, Equatable, Hashable {
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
    public let provider:     Provider
    public let url:          String
    public let identifier:   String
    public var title:        String?
    public var thumbnailUrl: NSURL?
    public var duration:     NSTimeInterval

    public var status:   Status { return _status }
    private var _status: Status

    private var _streamUrl:  NSURL?
    private var youtubeVideo: XCDYouTubeVideo?
    public var streamUrl: NSURL? {
        if let video = youtubeVideo {
            return video.streamURLs[Track.youTubeVideoQuality.rawValue] as? NSURL
        } else if let url = _streamUrl {
            return  url
        }
        return nil
    }

    public var hashValue: Int {
        return "\(provider):\(identifier)".hashValue
    }

    public init(provider: Provider, url: String, identifier: String, title: String?) {
        self.provider   = provider
        self.url        = url
        self.identifier = identifier
        self.title      = title
        self.duration   = 0 as NSTimeInterval
        self._status    = .Init
    }

    public init(json: JSON) {
        provider    = Provider(rawValue: json["provider"].stringValue)!
        title       = nil
        url         = json["url"].stringValue
        identifier  = json["identifier"].stringValue
        duration    = 0 as NSTimeInterval
        _status     = .Init
    }

    public init(store: TrackStore) {
        provider    = Provider(rawValue: store.providerRaw)!
        title       = store.title
        url         = store.url
        identifier  = store.identifier
        duration    = NSTimeInterval(store.duration)
        if let url = NSURL(string: store.streamUrl) {
            _streamUrl    = url
            _status       = .Available
        } else {
            _status       = .Init
        }
        if let url = NSURL(string: store.thumbnailUrl) {
            thumbnailUrl = url
        }
    }

    public func create() -> Bool {
        return TrackStore.create(self)
    }

    public func save() -> Bool {
        return TrackStore.save(self)
    }

    public func updateProperties(track: SoundCloudKit.Track) {
        title      = track.title
        duration   = NSTimeInterval(track.duration / 1000)
        _streamUrl = NSURL(string: track.streamUrl + "?client_id=" + APIClient.clientId)
        _status    = .Available
        if let url = track.thumbnailURL {
            thumbnailUrl = url
        }
//      save()
    }
    
    public func updatePropertiesWithYouTubeVideo(video: XCDYouTubeVideo) {
        youtubeVideo   = video
        title          = video.title
        duration       = video.duration
        thumbnailUrl   = video.mediumThumbnailURL
        _status        = .Available
//      save()
    }

    internal func toStoreObject() -> TrackStore {
        var store            = TrackStore()
        store.url            = url
        store.providerRaw    = provider.rawValue
        store.identifier     = identifier
        if let _title        = title                        { store.title        = _title }
        if let _streamUrl    = streamUrl?.absoluteString    { store.streamUrl    = _streamUrl }
        if let _thumbnailUrl = thumbnailUrl?.absoluteString { store.thumbnailUrl = _thumbnailUrl }
        store.duration       = Int(duration)

        return store
    }

    public func fetchTrackDetail(errorOnFailure: Bool) -> SignalProducer<Track, NSError>{
        _status = .Loading
        switch provider {
        case .Youtube:
            return SignalProducer<Track, NSError> { (sink, disposable) in
                XCDYouTubeClient.defaultClient().fetchVideo(self.identifier).start(
                    next: { video in
                        self.updatePropertiesWithYouTubeVideo(video)
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, error: { error in
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }, completed: {
                    }, interrupted: {
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    })
                return
            }
        case .SoundCloud:
            return SignalProducer<Track, NSError> { (sink, disposable) in
                let c = SoundCloudKit.APIClient()
                typealias R = SoundCloudKit.APIClient.Router
                c.fetchItem(R.Track(self.identifier)) { (req: NSURLRequest, res: NSHTTPURLResponse?, track: SoundCloudKit.Track?, error: NSError?) -> Void in
                    if let e = error {
                        self._status = .Unavailable
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    } else {
                        self.updateProperties(track!)
                        sink.put(.Next(Box(self)))
                        sink.put(.Completed)
                    }
                }
                return
            }
        }
    }

    public class func findBy(#url: String) -> Track? {
        if let store = TrackStore.findBy(url: url) {
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
