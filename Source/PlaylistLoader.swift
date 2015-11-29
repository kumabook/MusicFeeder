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

public class PlaylistLoader {
    public let playlist:    Playlist
    public var disposables: [Disposable]
    public init(playlist: Playlist) {
        self.playlist = playlist
        disposables   = []
    }

    deinit {
        dispose()
    }

    public func dispose() {
        disposables.forEach {
            $0.dispose()
        }
        disposables = []
    }

    public func fetchTracks() {
        for track in playlist.getTracks() {
            track.checkExpire()
        }
        var pairs: [(Int, Track)] = []
        for i in 0..<playlist.getTracks().count {
            let pair = (i, playlist.getTracks()[i])
            pairs.append(pair)
        }

        pairs.forEach {
            disposables.append(self.fetchTrack($0.0, track: $0.1).start())
        }
    }

    public func fetchTrack(index: Int, track: Track) -> SignalProducer<(Int, Track), NSError> {
        weak var _self = self
        return track.fetchTrackDetail(false).map { _track -> (Int, Track) in
            if let __self = _self {
                Playlist.notifyChange(.TrackUpdated(__self.playlist, _track))
                __self.playlist.sink(.Next(PlaylistEvent.Load(index: index)))
            }
            return (index, _track)
        }
    }
}
