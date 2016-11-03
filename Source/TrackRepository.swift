//
//  TrackRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/10/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

open class TrackRepository {
    open static var sharedInstance: TrackRepository = TrackRepository()

    open func getCacheTrackStore(_ id: String) -> TrackStore? {
        if let entity = TrackCacheSet.get(id), let store = entity.item {
            return store
        }
        return nil
    }

    open func cacheTrack(_ track: Track) {
        let _ = TrackCacheSet.set(track.id, item: track)
    }
}
