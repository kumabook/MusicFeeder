//
//  WallRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/05/18.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift
import FeedlyKit
import SwiftyJSON

open class WallRepository {
    public enum State {
        case cacheOnly
        case cacheOnlyFetching
        case normal
        case fetching
        case updating
        case error
    }
    public enum Event {
        case startLoading
        case completeLoading
        case failToLoad(Error)
        case startUpdating
        case failToUpdate(Error)
    }
    var id: String
    open fileprivate(set) var wall:       Wall?
    open fileprivate(set) var cachedWall: Wall?
    open                  var defaultWall: Wall = Wall(id: "default", label: "", resources: [])

    open var state:           State
    open var signal:          Signal<Event, NSError>
    fileprivate var observer: Signal<Event, NSError>.Observer
    open fileprivate(set) var apiClient = CloudAPIClient.shared

    public init(id: String) {
        let pipe = Signal<Event, NSError>.pipe()
        self.id  = id
        signal   = pipe.0
        observer = pipe.1
        state    = .cacheOnly
        loadCacheItems()
    }
    open func fetch() {
        if state != .cacheOnly && state != .normal && state != .error {
            return
        }
        if state == .cacheOnly {
            state = .cacheOnlyFetching
        } else {
            state = .fetching
        }
        observer.send(value: .startLoading)
        apiClient.fetchWall(id).on(
            failed: { error in
                print("Failed to fetch wall \(error)")
        }, completed: {
            self.state = .normal
            self.observer.send(value: .completeLoading)
        }, value: { wall in
            self.wall = wall
        }).start()
    }
    open func loadCacheItems() {
        apiClient.fetchWall(id, useCache: true).on(failed: { error in
            print("No cache")
        }, completed: {
             self.observer.send(value: .completeLoading)
        }, value: { wall in
            self.wall = wall
        }).start()
    }
}
