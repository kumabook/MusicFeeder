//
//  TrackStreamLoader.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/31/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import FeedlyKit
import ReactiveCocoa
import Result

public class TrackStreamLoader: PaginatedCollectionLoader<PaginatedTrackCollection, Track> {
    public typealias State = PaginatedCollectionLoaderState
    public typealias Event = PaginatedCollectionLoaderEvent
    
    public private(set) var feedlyClient        = CloudAPIClient.sharedInstance
    public private(set) var pinkspiderClient    = PinkSpiderAPIClient.sharedInstance

    public private(set) var playlistQueue: PlaylistQueue = PlaylistQueue(playlists: [])

    public override func fetchCollection(streamId streamId: String, paginationParams: MusicFeeder.PaginationParams)-> SignalProducer<PaginatedTrackCollection, NSError> {
        return feedlyClient.fetchTracksOf(streamId, paginationParams: paginationParams)
    }

    deinit {
        dispose()
    }
    
    public func fetchTracks()       { fetchItems() }
    public func fetchLatestTracks() { fetchLatestItems() }
    
    public var tracks:   [Track]    { return self.items }
    public var detailLoader:        Disposable?

    
    public override func itemsUpdated() {
        detailLoader?.dispose()
        detailLoader = tracks.map({ track in
            track.fetchDetail().map {
                self.playlistQueue.enqueue(Playlist(id: track.id, title: track.title ?? "No title", tracks: [track]))
                self.observer.sendNext(.CompleteLoadingTrackDetail(track))
                return $0
            }
        }).reduce(SignalProducer<Track, NSError>.empty, combine: { (currentSignal, nextSignal) in
            currentSignal.concat(nextSignal)
        }).on().start()
    }

    public override init(stream: Stream, unreadOnly: Bool, perPage: Int) {
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }
}
