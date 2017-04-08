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
                  artist:       playlistItem.channelTitle,
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
