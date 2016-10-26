//
//  TrackStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/31/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result

public class TrackStreamRepository: PaginatedCollectionRepository<PaginatedTrackCollection, Track> {
    public typealias State = PaginatedCollectionRepositoryState
    public typealias Event = PaginatedCollectionRepositoryEvent
    
    public private(set) var feedlyClient        = CloudAPIClient.sharedInstance
    public private(set) var pinkspiderClient    = PinkSpiderAPIClient.sharedInstance

    public private(set) var playlistQueue: PlaylistQueue = PlaylistQueue(playlists: [])

    public override func fetchCollection(streamId streamId: String, paginationParams: MusicFeeder.PaginationParams)-> SignalProducer<PaginatedTrackCollection, NSError> {
        return feedlyClient.fetchTracksOf(streamId, paginationParams: paginationParams)
    }

    deinit {
        dispose()
    }
    
    public var detailLoader: Disposable?
    
    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }
    // MARK: - PaginatedCollectionRepository protocol
    
    public override func addCacheItems(items: [Track]) {
        TrackCacheList.findOrCreate(stream.streamId).add(items)
    }
    public override func loadCacheItems() {
        cacheItems = TrackCacheList.findOrCreate(stream.streamId).items.map { Track(store: $0 as! TrackStore) }
    }
    public override func clearCacheItems() {
        TrackCacheList.findOrCreate(stream.streamId).clear()
    }
    public override func cacheItemsUpdated() {
        QueueScheduler().schedule() {
            self.cacheItems.forEach {
                $0.loadPropertiesFromCache(false)
            }
            UIScheduler().schedule() {
                self.observer.sendNext(.CompleteLoadingNext)
            }
        }
    }
    public override func itemsUpdated() {
        detailLoader?.dispose()
        detailLoader = items.map({ track in
            track.fetchDetail().map {
                self.playlistQueue.enqueue(Playlist(id: track.id, title: track.title ?? "No title", tracks: [track]))
                self.observer.sendNext(.CompleteLoadingTrackDetail(track))
                return $0
            }
        }).reduce(SignalProducer<Track, NSError>.empty, combine: { (currentSignal, nextSignal) in
            currentSignal.concat(nextSignal)
        }).on().start()
    }
}
