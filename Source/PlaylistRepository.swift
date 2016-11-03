//
//  PlaylistRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

open class PlaylistRepository {
    open let playlist: Playlist
    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    deinit {}

    open func fetchTracks() -> SignalProducer<(Int, Track), NSError> {
        return playlist.getTracks().enumerated().map {
            fetchTrack($0, track: $1)
        }.reduce(SignalProducer<(Int, Track), NSError>.empty, { (c, n) in c.concat(n) })
    }

    fileprivate func fetchTrack(_ index: Int, track: Track) -> SignalProducer<(Int, Track), NSError> {
        return track.fetchDetail().map { _track -> (Int, Track) in
            Playlist.notifyChange(.trackUpdated(self.playlist, track))
            self.playlist.observer.send(value: PlaylistEvent.load(index: index))
            return (index, track)
        }
    }
}
