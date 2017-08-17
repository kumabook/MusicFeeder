//
//  YouTubeClient.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/04/07.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import YouTubeKit
import ReactiveSwift
import SwiftyJSON

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

public protocol YouTubeVideo {
    var identifier: String { get }
    var title: String { get }
    var duration: TimeInterval { get }
    var smallThumbnailURL: URL? { get }
    var mediumThumbnailURL: URL? { get }
    var largeThumbnailURL: URL? { get }
    var streamURLs: [AnyHashable : URL] { get }
    var expirationDate: Date? { get }
}

public protocol YouTubeAPIClient {
    func fetchVideo(_ identifier: String) -> SignalProducer<YouTubeVideo, NSError>
}

extension Playlist {
    public convenience init(id: String, title: String, items: PaginatedResponse<PlaylistItem>) {
        self.init(id: id, title: title, tracks: items.items.map {
            Track(playlistItem: $0)
        })
    }
}

extension Track {
    public convenience init(playlistItem: YouTubeKit.PlaylistItem) {
        self.init(id:           "",
                  provider:     .youTube,
                  url:          "https://www.youtube.com/watch/?v=\(playlistItem.videoId)",
                  identifier:   playlistItem.videoId,
                  title:        playlistItem.title,
                  thumbnailUrl: playlistItem.thumbnailURL,
                  artworkUrl:   playlistItem.thumbnailURL,
                  audioUrl:     nil,
                  ownerId:      playlistItem.channelId,
                  ownerName:    playlistItem.channelTitle,
                  status:       .available,
                  expiresAt:    Int64.max,
                  publishedAt:  0,
                  createdAt:    0,
                  updatedAt:    0,
                  state:        EnclosureState.alive,
                  isLiked:      nil,
                  isSaved:      nil,
                  isPlayed:     nil)
    }
}

extension YouTubeKit.APIClient {
    public func fetchGuideCategories(regionCode: String, pageToken: String?) -> SignalProducer<PaginatedResponse<GuideCategory>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchGuideCategories(regionCode: regionCode, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }

    public func fetchMyChannels(pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.MyChannel>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchMyChannels(pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    
    public func fetchChannels(of category: YouTubeKit.GuideCategory, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Channel>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchChannels(of: category, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    
    public func fetchSubscriptions(pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Subscription>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchSubscriptions(pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }

    public func searchChannel(by query: String?, pageToken: String?) -> SignalProducer<PaginatedResponse<Channel>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.searchChannel(by: query, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    
    public func fetchPlaylist(_ id: String, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Playlist>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchPlaylist(id, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    
    public func fetchMyPlaylists(pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.Playlist>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchMyPlaylists(pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }

    public func fetchPlaylistItems(_ id: String, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchPlaylistItems(id, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
    
    public func fetchPlaylistItems(of playlist: YouTubeKit.Playlist, pageToken: String?) -> SignalProducer<PaginatedResponse<YouTubeKit.PlaylistItem>, NSError> {
        return SignalProducer { (observer, disposable) in
            let request = self.fetchPlaylistItems(of: playlist, pageToken: pageToken) { response in
                if let e = response.result.error {
                    observer.send(error: e as NSError)
                } else if let value = response.result.value {
                    observer.send(value: value)
                    observer.sendCompleted()
                }
            }
            disposable.add {
                request.cancel()
            }
        }
    }
}
