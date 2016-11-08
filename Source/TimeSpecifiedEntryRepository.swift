//
//  TimeSpecifiedEntryRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/30/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

public class TimeSpecifiedEntryRepository: EntryRepository {
    var newerThan: Int64
    var olderThan: Int64

    var name: String

    override public var cacheKey: String {
        return "\(stream.streamId)-\(name)"
    }

    public init(stream: Stream, unreadOnly: Bool, perPage: Int, newerThan: Int64, olderThan: Int64, name: String) {
        self.newerThan = newerThan
        self.olderThan = olderThan
        self.name      = name
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    public override var paginationParams: MusicFeeder.PaginationParams {
        let params          = MusicFeeder.PaginationParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        params.newerThan    = newerThan
        params.olderThan    = olderThan
        return params
    }
    
    public override var paginationParamsForLatest: MusicFeeder.PaginationParams {
        let params        = MusicFeeder.PaginationParams()
        params.unreadOnly = unreadOnly
        params.count      = perPage
        params.newerThan  = newerThan
        params.olderThan  = olderThan
        return params
    }
}