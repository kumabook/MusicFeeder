//
//  PlaylistLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/5/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import Box

public class PlaylistLoader {
    public let playlist: Playlist
    public var signal:   SignalProducer<(Int, Track), NSError>?
    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    deinit {
        
    }

    public func dispose() {
    }

    public func fetchTracks() -> SignalProducer<(Int, Track), NSError> {
        var pairs: [(Int, Track)] = []
        for i in 0..<playlist.getTracks().count {
            let pair = (i, playlist.getTracks()[i])
            pairs.append(pair)
        }
        signal = pairs.map {
            self.fetchTrack($0.0, track: $0.1)
            }.reduce(SignalProducer<(Int, Track), NSError>.empty, combine: { (signal, nextSignal) in
                signal |> concat(nextSignal)
            })
        return signal!
    }

    public func fetchTrack(index: Int, track: Track) -> SignalProducer<(Int, Track), NSError> {
        weak var _self = self
        return track.fetchTrackDetail(false) |> map { _track -> (Int, Track) in
            if let __self = _self {
                Playlist.notifyChange(.TrackUpdated(__self.playlist, _track))
                __self.playlist.sink.put(.Next(Box(PlaylistEvent.Load(index: index))))
            }
            return (index, _track)
        }
    }

    func uploadTrackToCacheServer() {
        
    }
}
