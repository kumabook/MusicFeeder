//
//  PlaylistRepository.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

public class PlaylistRepository {
    public let playlist: Playlist
    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    deinit {}

    public func fetchTracks() -> SignalProducer<(Int, Track), NSError> {
        return playlist.getTracks().enumerate().map {
            fetchTrack($0, track: $1)
        }.reduce(SignalProducer<(Int, Track), NSError>.empty, combine: { (c, n) in c.concat(n) })
    }

    private func fetchTrack(index: Int, track: Track) -> SignalProducer<(Int, Track), NSError> {
        return track.fetchDetail().map { _track -> (Int, Track) in
            Playlist.notifyChange(.TrackUpdated(self.playlist, track))
            self.playlist.observer.sendNext(PlaylistEvent.Load(index: index))
            return (index, track)
        }
    }
}
