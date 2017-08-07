//
//  EnclosureMixRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/31.
//  Copyright © 2017 kumabook. All rights reserved.
//

import FeedlyKit
import ReactiveSwift
import Result
import Realm

open class TrackMixRepository: TrackStreamRepository {
    var newerThan: Int64?
    var olderThan: Int64?
    var name:      String
    var type:      MixType

    public init(stream: FeedlyKit.Stream, unreadOnly: Bool, perPage: Int, name: String, type: MixType, newerThan: Int64?, olderThan: Int64?) {
        self.newerThan = newerThan
        self.olderThan = olderThan
        self.name      = name
        self.type      = type
        super.init(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }

    open override var paginationParams: FeedlyKit.PaginationParams {
        let params          = MixParams()
        params.continuation = continuation
        params.unreadOnly   = unreadOnly
        params.count        = perPage
        params.newerThan    = newerThan
        params.olderThan    = olderThan
        params.type         = type
        return params
    }

    open override var paginationParamsForLatest: FeedlyKit.PaginationParams {
        let params        = MixParams()
        params.unreadOnly = unreadOnly
        params.count      = perPage
        params.newerThan  = newerThan
        params.olderThan  = olderThan
        params.type       = type
        return params
    }

    open override func fetchCollection(streamId: String, paginationParams paginatedParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedEnclosureCollection<Track>, NSError> {
        if let mixParams = paginationParams as? MixParams {
            return feedlyClient.fetchEnclosureMixOf(streamId, paginationParams: mixParams, useCache: useCache)
        } else {
            fatalError("Invalid params")
        }
    }
    open override func renew() -> TrackMixRepository {
        return TrackMixRepository(stream: stream, unreadOnly: unreadOnly, perPage: perPage, name: name, type: type, newerThan: newerThan, olderThan: olderThan)
    }
}
