//
//  Subscribable.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/14/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import FeedlyKit

public protocol Subscribable {
    func toSubscription() -> Subscription
}
