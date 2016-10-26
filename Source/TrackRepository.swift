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

public class TrackRepository {
    public static var sharedInstance: TrackRepository = TrackRepository()

    public func getCacheTrackStore(id: String) -> TrackStore? {
        if let entity = TrackCacheSet.get(id), store = entity.item {
            return store
        }
        return nil
    }

    public func cacheTrack(track: Track) {
        TrackCacheSet.set(track.id, item: track)
    }
}