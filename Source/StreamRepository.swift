
//
//  StreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveSwift
import Result

open class StreamRepository {
    public enum State {
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
        case create(Subscription)
        case remove(Subscription)
    }

    var apiClient: CloudAPIClient { return CloudAPIClient.sharedInstance }

    open var state:                State
    open var signal:               Signal<Event, NSError>
    fileprivate var observer:            Signal<Event, NSError>.Observer
    open var streamListOfCategory: [FeedlyKit.Category: [FeedlyKit.Stream]]
    open var uncategorized:        FeedlyKit.Category
    open var isLoggedIn: Bool {
        return CloudAPIClient.isLoggedIn
    }
    open var categories: [FeedlyKit.Category] {
        return streamListOfCategory.keys.sorted(by: { (first, second) -> Bool in
            return first == self.uncategorized || first.label > second.label
        })
    }
    open var uncategorizedStreams: [FeedlyKit.Stream] {
        return streamListOfCategory[uncategorized]!
    }

    public init() {
        state                = .normal
        streamListOfCategory = [:]
        let pipe = Signal<Event, NSError>.pipe()
        signal               = pipe.0
        observer             = pipe.1
        uncategorized        = FeedlyKit.Category.Uncategorized()
        if let userId = CloudAPIClient.profile?.id {
            uncategorized = FeedlyKit.Category.Uncategorized(userId)
        }
        streamListOfCategory[uncategorized] = []
    }

    deinit {
        dispose()
    }

    open func dispose() {}

    open func getStream(id: String) -> FeedlyKit.Stream? {
        return streamListOfCategory.values.flatMap { $0 }.filter { $0.streamId == id }.first
    }

    fileprivate func addSubscription(_ subscription: Subscription) {
        let _ = SubscriptionStore.create(subscription)
        let categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            if (streamListOfCategory[category]!).index(of: subscription) == nil {
                streamListOfCategory[category]!.append(subscription)
            }
        }
    }

    fileprivate func removeSubscription(_ subscription: Subscription) {
        SubscriptionStore.remove(subscription)
        let  categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            let index = (self.streamListOfCategory[category]!).index(of: subscription)
            if let i = index {
                streamListOfCategory[category]!.remove(at: i)
            }
        }
    }

    open func refresh() {
        state = .fetching
        observer.send(value: .startLoading)
        let _ = loadLocalSubscriptions().on(completed: {
            self.observer.send(value: .completeLoading)
        }).start()
        if isLoggedIn {
            apiClient.fetchSubscriptions().on(
                failed: { error in
                    CloudAPIClient.handleError(error: error)
                    self.state = .error
                    self.observer.send(value: .failToLoad(error))
            }, completed: {
                self.state = .normal
                self.observer.send(value: .completeLoading)
            }, value: { subscriptions in
                self.updateSubscriptions(subscriptions)
            }).start()
        }
    }
    
    open func updateSubscriptions(_ subscriptions: [Subscription]) {
        for subscription in subscriptions {
            let _ = SubscriptionStore.create(subscription)
        }
    }

    open func loadLocalSubscriptions() -> SignalProducer<[FeedlyKit.Category: [FeedlyKit.Stream]], NSError> {
        return SignalProducer { (_observer, disposable) in
            for category in Category.findAll() {
                self.streamListOfCategory[category] = [] as [FeedlyKit.Stream]
            }
            for subscription in Subscription.findAll() {
                let categories = subscription.categories.count > 0 ? subscription.categories : [self.uncategorized]
                for category in categories {
                    if (self.streamListOfCategory[category]!).index(of: subscription) == nil {
                        self.streamListOfCategory[category]!.append(subscription)
                    }
                }
            }
            for key in self.streamListOfCategory.keys {
                if self.streamListOfCategory[key]!.isEmpty {
                    if key != self.uncategorized {
                        self.streamListOfCategory.removeValue(forKey: key)
                    }
                }
            }
            _observer.send(value: self.streamListOfCategory)
            _observer.sendCompleted()
            return
        }
    }

    open func createCategory(_ label: String) -> FeedlyKit.Category? {
        if let profile = CloudAPIClient.profile {
            let category = FeedlyKit.Category(label: label, profile: profile)
            streamListOfCategory[category] = []
            return category
        } else {
            let category = FeedlyKit.Category(id: "\(label)", label: label)
            streamListOfCategory[category] = []
            return category
        }
    }

    open func subscribeTo(_ stream: FeedlyKit.Stream, categories: [FeedlyKit.Category]) -> SignalProducer<Subscription, NSError> {
        return subscribeTo(Subscription(id: stream.streamId,
                                     title: stream.streamTitle,
                                 visualUrl: stream.thumbnailURL?.absoluteString,
                                categories: categories))
    }

    open func subscribeTo(_ subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (_observer, disposable) in
            self.state = .updating
            self.observer.send(value: .startUpdating)
            if !self.isLoggedIn {
                self.addSubscription(subscription)
                self.state = .normal
                self.observer.send(value: .create(subscription))
                _observer.send(value: subscription)
                _observer.sendCompleted()
            } else {
                let _ = self.apiClient.subscribeTo(subscription) { response in
                    if let e = response.error, response.response?.statusCode ?? 0 != 409 {
                        CloudAPIClient.handleError(error: e)
                        self.state = .error
                        self.observer.send(value: .failToUpdate(e))
                        _observer.send(error: CloudAPIClient.sharedInstance.buildError(error: e as NSError, response: response.response))
                    } else {
                        self.addSubscription(subscription)
                        self.state = .normal
                        self.observer.send(value: .create(subscription))
                        _observer.send(value: subscription)
                        _observer.sendCompleted()
                    }
                }
            }
        }
    }

    open func unsubscribeTo(_ subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (_observer, disposable) in
            self.state = .updating
            self.observer.send(value: .startUpdating)
            if !self.isLoggedIn {
                self.removeSubscription(subscription)
                self.state = .normal
                self.observer.send(value: .remove(subscription))
                return
            }
            let _ = self.apiClient.unsubscribeTo(subscription.id, completionHandler: { response in
                if let e = response.error, response.response?.statusCode ?? 0 != 404 {
                    self.state = .error
                    self.observer.send(value: .failToUpdate(e))
                    _observer.send(error: CloudAPIClient.sharedInstance.buildError(error: e as NSError, response: response.response))
                    _observer.sendCompleted()
                } else {
                    SubscriptionStore.remove(subscription)
                    self.removeSubscription(subscription)
                    self.state = .normal
                    self.observer.send(value: .remove(subscription))
                    _observer.send(value: subscription)
                    _observer.sendCompleted()
                }
            })
        }
    }

    open func moveSubscriptionTo(_ sourceIndex: Int, toIndex:Int) -> PersistentResult {
        let result = SubscriptionStore.moveSubscriptionInSharedList(sourceIndex, toIndex: toIndex)
        let _ = loadLocalSubscriptions().start()
        return result
    }
}
