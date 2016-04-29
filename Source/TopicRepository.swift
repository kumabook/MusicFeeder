//
//  TopicRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/29/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FeedlyKit

public class TopicRepository {
    public static var sharedInstance: TopicRepository = TopicRepository(cloudApiClient: CloudAPIClient.sharedInstance)
    public private(set) var items: [Topic] = []
    public var cloudApiClient: CloudAPIClient
    public init(cloudApiClient: CloudAPIClient) {
        self.cloudApiClient = cloudApiClient
    }
    public func fetch() -> SignalProducer<Void, NSError> {
        return cloudApiClient.fetchTopics().map { topics in
            self.items = topics
            return
        }
    }
}