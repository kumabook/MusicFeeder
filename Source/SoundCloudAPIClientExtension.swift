//
//  SoundCloudAPIClientExtension.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/04/06.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SoundCloudKit
import ReactiveSwift
import Alamofire

extension Playlist {
    public convenience init(playlist: SoundCloudKit.Playlist) {
        self.init(id: String(playlist.id), title: playlist.title, tracks: playlist.tracks.map {
            Track(track: $0)
        })
    }
}

extension Track {
    public convenience init(track: SoundCloudKit.Track) {
        self.init(id:       "",
              provider:     .soundCloud,
              url:          track.permalinkUrl,
              identifier:   String(track.id),
              title:        track.title,
              duration:     TimeInterval(track.duration),
              thumbnailUrl: track.thumbnailURL,
              artworkUrl:   track.artworkURL,
              audioUrl:     URL(string: track.streamUrl),
              artist:       track.user.username,
              status:       .available,
              expiresAt:    Int64.max,
              publishedAt:  0,
              createdAt:    0,
              updatedAt:    0,
              state:        EnclosureState.alive,
              isLiked:      nil,
              isSaved:      nil,
              isPlayed:     nil)
        self.soundcloudTrack = track
    }
}

extension SoundCloudKit.APIClient {
    public func fetchItem<T: JSONInitializable>(_ route: Router) -> SignalProducer<T, NSError> {
        return SignalProducer { observer, disposable in
            self.fetchItem(route, callback: { (req: URLRequest?, res: HTTPURLResponse?, result: Result<T>) in
                switch result {
                case .success(let value):
                    observer.send(value: value)
                    observer.sendCompleted()
                case .failure(let error):
                    observer.send(error: error as NSError)
                }
            })
        }
    }
    public func fetchItems<T: JSONInitializable>(_ route: Router) -> SignalProducer<[T], NSError> {
        return SignalProducer { observer, disposable in
            self.fetchItems(route, callback: { (req: URLRequest?, res: HTTPURLResponse?, result: Result<[T]>) in
                switch result {
                case .success(let value):
                    observer.send(value: value)
                    observer.sendCompleted()
                case .failure(let error):
                    observer.send(error: error as NSError)
                }
            })
        }
    }
    public func fetchUsers(_ query: String) -> SignalProducer<[User], NSError> {
        return fetchItems(Router.users(query))
    }
    
    public func fetchMe() -> SignalProducer<User, NSError> {
        return fetchItem(Router.me)
    }
    
    public func fetchUser(_ userId: String) -> SignalProducer<User, NSError> {
        return fetchItem(Router.user(userId))
    }
    
    public func fetchTrack(_ trackId: String) -> SignalProducer<SoundCloudKit.Track, NSError> {
        return fetchItem(Router.track(trackId))
    }
    
    public func fetchTracksOf(_ user: User) -> SignalProducer<[SoundCloudKit.Track], NSError> {
        return fetchItems(Router.tracksOfUser(user))
    }
    
    public func fetchPlaylistsOf(_ user: User) -> SignalProducer<[SoundCloudKit.Playlist], NSError> {
        return fetchItems(Router.playlistsOfUser(user))
    }
    
    public func fetchFollowingsOf(_ user: User) -> SignalProducer<[User], NSError> {
        return self.fetchItems(Router.followingsOfUser(user))
    }
    
    public func fetchFavoritesOf(_ user: User) -> SignalProducer<[SoundCloudKit.Track], NSError> {
        return self.fetchItems(Router.favoritesOfUser(user))
    }
    
    public func fetchActivities() -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.activities)
    }
    
    public func fetchNextActivities(_ nextHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.nextActivities(nextHref))
    }
    
    public func fetchLatestActivities(_ futureHref: String) -> SignalProducer<ActivityList, NSError> {
        return self.fetchItem(Router.futureActivities(futureHref))
    }
    
    public func fetchPlaylist(_ id: Int) -> SignalProducer<SoundCloudKit.Playlist, NSError> {
        return self.fetchItem(Router.playlist("\(id)"))
    }
}
