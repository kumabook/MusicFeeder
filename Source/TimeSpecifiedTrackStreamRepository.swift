//
//  RankingTrackStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/30/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

open class TimeSpecifiedTrackStreamRepository: TrackStreamRepository {
    var newerThan: Int64
    var olderThan: Int64
    
    public init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int, newerThan: Int64, olderThan: Int64) {
        self.newerThan = newerThan
        self.olderThan = olderThan
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }
    
    open override var paginationParams: MusicFeeder.PaginationParams {
        let params          = MusicFeeder.PaginationParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        params.newerThan    = newerThan
        params.olderThan    = olderThan
        return params
    }
    
    open override var paginationParamsForLatest: MusicFeeder.PaginationParams {
        let params        = MusicFeeder.PaginationParams()
        params.unreadOnly = unreadOnly
        params.count      = perPage
        params.newerThan  = newerThan
        params.olderThan  = olderThan
        return params
    }
}
