//
//  TrackStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/31/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import FeedlyKit
import ReactiveSwift
import Result

open class TrackStreamRepository: EnclosureStreamRepository<Track> {
    open static var sharedPipe: (Signal<Track, NSError>, Signal<Track, NSError>.Observer)! = Signal<Track, NSError>.pipe()
    open fileprivate(set) var pinkspiderClient             = PinkSpiderAPIClient.sharedInstance
    open fileprivate(set) var playlistQueue: PlaylistQueue = PlaylistQueue(playlists: [])

    // MARK: - PaginatedCollectionRepository protocol
    
    open override func addCacheItems(_ items: [Track]) {
        let _ = TrackCacheList.findOrCreate(cacheKey).add(items)
    }
    open override func loadCacheItems() {
        cacheItems = realize(TrackCacheList.findOrCreate(cacheKey).items).map { Track(store: $0 as! TrackStore) }
    }
    open override func clearCacheItems() {
        let _ = TrackCacheList.findOrCreate(cacheKey).clear()
    }
    open override func cacheItemsUpdated() {
        QueueScheduler().schedule() {
            self.cacheItems.forEach {
                $0.loadPropertiesFromCache(false)
            }
            UIScheduler().schedule() {
                self.observer.send(value: .completeLoadingNext)
            }
        }
    }
    open override func itemsUpdated() {
        detailLoader?.dispose()
        self.playlistQueue = PlaylistQueue(playlists: [])
        QueueScheduler().schedule() {
            self.items.forEach {
                $0.loadPropertiesFromCache(true)
            }
            UIScheduler().schedule() {
                self.observer.send(value: .completeLoadingNext)
            }
            self.items.forEach {
                let playlist = Playlist(id: $0.id, title: $0.title ?? "No title", tracks: [$0])
                self.playlistQueue.enqueue(playlist)
            }
            self.detailLoader = self.items.map({ track in
                return track.fetchDetail().map {
                    UIScheduler().schedule() {
                        self.observer.send(value: .completeLoadingTrackDetail(track))
                    }
                    return $0
                }
            }).reduce(SignalProducer<Track, NSError>.empty, { (currentSignal, nextSignal) in
                currentSignal.concat(nextSignal)
            }).on(completed: {
            }).start()
        }
    }
}
