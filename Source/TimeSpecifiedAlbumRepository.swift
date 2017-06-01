//
//  TimeSpecifiedAlbumRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/06/01.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

open class TimeSpecifiedAlbumStreamRepository: AlbumStreamRepository {
    var newerThan: Int64?
    var olderThan: Int64?
    var name: String
    
    override open var cacheKey: String {
        return "\(stream.streamId)-\(name)"
    }
    
    public init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int, newerThan: Int64?, olderThan: Int64?, name: String) {
        self.newerThan = newerThan
        self.olderThan = olderThan
        self.name      = name
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
