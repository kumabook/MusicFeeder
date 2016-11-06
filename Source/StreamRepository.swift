
//
//  StreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveCocoa
import Result

public class StreamRepository {
    public enum State {
        case Normal
        case Fetching
        case Updating
        case Error
    }

    public enum Event {
        case StartLoading
        case CompleteLoading
        case FailToLoad(ErrorType)
        case StartUpdating
        case FailToUpdate(ErrorType)
        case Create(Subscription)
        case Remove(Subscription)
    }

    var apiClient: CloudAPIClient { return CloudAPIClient.sharedInstance }

    public var state:                State
    public var signal:               Signal<Event, NSError>
    private var observer:            Signal<Event, NSError>.Observer
    public var streamListOfCategory: [FeedlyKit.Category: [Stream]]
    public var uncategorized:        FeedlyKit.Category
    public var isLoggedIn: Bool {
        return CloudAPIClient.isLoggedIn
    }
    public var categories: [FeedlyKit.Category] {
        return streamListOfCategory.keys.sort({ (first, second) -> Bool in
            return first == self.uncategorized || first.label > second.label
        })
    }
    public var uncategorizedStreams: [Stream] {
        return streamListOfCategory[uncategorized]!
    }

    public init() {
        state                = .Normal
        streamListOfCategory = [:]
        let pipe = Signal<Event, NSError>.pipe()
        signal               = pipe.0
        observer             = pipe.1
        uncategorized        = FeedlyKit.Category.Uncategorized()
        if let userId = CloudAPIClient.profile?.id {
            uncategorized = FeedlyKit.Category.Uncategorized(userId)
        }
        streamListOfCategory[uncategorized] = []
        loadLocalSubscriptions()
    }

    deinit {
        dispose()
    }

    public func dispose() {}

    public func getStream(id id: String) -> Stream? {
        return streamListOfCategory.values.flatMap { $0 }.filter { $0.streamId == id }.first
    }

    private func addSubscription(subscription: Subscription) {
        SubscriptionStore.create(subscription)
        let categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            if (streamListOfCategory[category]!).indexOf(subscription) == nil {
                streamListOfCategory[category]!.append(subscription)
            }
        }
    }

    private func removeSubscription(subscription: Subscription) {
        SubscriptionStore.remove(subscription)
        let  categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            let index = (self.streamListOfCategory[category]!).indexOf(subscription)
            if let i = index {
                streamListOfCategory[category]!.removeAtIndex(i)
            }
        }
    }

    public func refresh() {
        state = .Fetching
        observer.sendNext(.StartLoading)
        apiClient.fetchSubscriptions().on(
            next: { subscriptions in
                self.updateSubscriptions(subscriptions)
            }, completed: {
                self.state = .Normal
                self.observer.sendNext(.CompleteLoading)
            }, failed: { error in
                CloudAPIClient.handleError(error: error)
                self.state = .Error
                self.observer.sendNext(.FailToLoad(error))
            }
        ).start()
    }
    
    public func updateSubscriptions(subscriptions: [Subscription]) {
        for subscription in subscriptions {
            SubscriptionStore.create(subscription)
        }
    }

    public func loadLocalSubscriptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        return SignalProducer { (_observer, disposable) in
            for category in Category.findAll() {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            self.streamListOfCategory[self.uncategorized] = []
            for subscription in Subscription.findAll() {
                let categories = subscription.categories.count > 0 ? subscription.categories : [self.uncategorized]
                for category in categories {
                    if (self.streamListOfCategory[category]!).indexOf(subscription) == nil {
                        self.streamListOfCategory[category]!.append(subscription)
                    }
                }
            }
            for key in self.streamListOfCategory.keys {
                if self.streamListOfCategory[key]!.isEmpty {
                    if key != self.uncategorized {
                        self.streamListOfCategory.removeValueForKey(key)
                    }
                }
            }
            _observer.sendNext(self.streamListOfCategory)
            _observer.sendCompleted()
            return
        }
    }

    public func createCategory(label: String) -> FeedlyKit.Category? {
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

    public func subscribeTo(stream: Stream, categories: [FeedlyKit.Category]) -> SignalProducer<Subscription, NSError> {
        return subscribeTo(Subscription(id: stream.streamId,
                                     title: stream.streamTitle,
                                 visualUrl: stream.thumbnailURL?.absoluteString,
                                categories: categories))
    }

    public func subscribeTo(subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (_observer, disposable) in
            self.state = .Updating
            self.observer.sendNext(.StartUpdating)
            if !self.isLoggedIn {
                self.addSubscription(subscription)
                self.state = .Normal
                self.observer.sendNext(.Create(subscription))
                _observer.sendNext(subscription)
                _observer.sendCompleted()
            } else {
                self.apiClient.subscribeTo(subscription) { response in
                    if let e = response.result.error where response.response?.statusCode ?? 0 != 409 {
                        CloudAPIClient.handleError(error: e)
                        self.state = .Error
                        self.observer.sendNext(.FailToUpdate(e))
                        _observer.sendFailed(CloudAPIClient.sharedInstance.buildError(e, response: response.response))
                    } else {
                        self.addSubscription(subscription)
                        self.state = .Normal
                        self.observer.sendNext(.Create(subscription))
                        _observer.sendNext(subscription)
                        _observer.sendCompleted()
                    }
                }
            }
        }
    }

    public func unsubscribeTo(subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (_observer, disposable) in
            self.state = .Updating
            self.observer.sendNext(.StartUpdating)
            if !self.isLoggedIn {
                self.removeSubscription(subscription)
                self.state = .Normal
                self.observer.sendNext(.Remove(subscription))
                return
            }
            self.apiClient.unsubscribeTo(subscription.id, completionHandler: { response in
                if let e = response.result.error where response.response?.statusCode ?? 0 != 404 {
                    self.state = .Error
                    self.observer.sendNext(.FailToUpdate(e))
                    _observer.sendFailed(CloudAPIClient.sharedInstance.buildError(e, response: response.response))
                    _observer.sendCompleted()
                } else {
                    SubscriptionStore.remove(subscription)
                    self.removeSubscription(subscription)
                    self.state = .Normal
                    self.observer.sendNext(.Remove(subscription))
                    _observer.sendNext(subscription)
                    _observer.sendCompleted()
                }
            })
        }
    }

    public func moveSubscriptionTo(sourceIndex: Int, toIndex:Int) -> PersistentResult {
        let result = SubscriptionStore.moveSubscriptionInSharedList(sourceIndex, toIndex: toIndex)
        loadLocalSubscriptions().start()
        return result
    }
}
