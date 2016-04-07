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
    public private(set) var musicfavClient      = MusicFavAPIClient.sharedInstance

    public override func fetchCollection(streamId streamId: String, paginationParams: MusicFeeder.PaginationParams)-> SignalProducer<PaginatedTrackCollection, NSError> {
        return feedlyClient.fetchTracksOf(streamId, paginationParams: paginationParams)
    }

    deinit {
        dispose()
    }
    
    public func fetchTracks()       { fetchItems() }
    public func fetchLatestTracks() { fetchLatestItems() }
    
    public var tracks:   [Track]    { return self.items }
    public var playlist: Playlist   { return Playlist(id: stream.streamId, title: stream.streamTitle, tracks: tracks) }
    public var detailLoader:        Disposable?

    
    public override func itemsUpdated() {
        detailLoader?.dispose()
        detailLoader = tracks.map({ track in
            track.fetchDetail().map {
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
