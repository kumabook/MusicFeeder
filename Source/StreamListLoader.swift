
//
//  StreamListLoader.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/15/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveCocoa
import Result

public class StreamListLoader {
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
    public var useCache: Bool
    public var categories: [FeedlyKit.Category] {
        return streamListOfCategory.keys.sort({ (first, second) -> Bool in
            return first == self.uncategorized || first.label > second.label
        })
    }
    public var uncategorizedStreams: [Stream] {
        return streamListOfCategory[uncategorized]!
    }

    public init(useCache: Bool = true) {
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
        self.useCache = useCache
    }

    deinit {
        dispose()
    }

    public func dispose() {}

    public func getStream(id id: String) -> Stream? {
        return streamListOfCategory.values.flatMap { $0 }.filter { $0.streamId == id }.first
    }

    private func addSubscription(subscription: Subscription) {
        let categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            if (streamListOfCategory[category]!).indexOf(subscription) == nil {
                streamListOfCategory[category]!.append(subscription)
            }
        }
    }

    private func removeSubscription(subscription: Subscription) {
        let  categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            let index = (self.streamListOfCategory[category]!).indexOf(subscription)
            if let i = index {
                streamListOfCategory[category]!.removeAtIndex(i)
            }
        }
    }

    public func refresh() -> SignalProducer<Void, NSError> {
        var signal: SignalProducer<[FeedlyKit.Category: [Stream]], NSError>
        if !CloudAPIClient.isLoggedIn || useCache {
            signal = self.fetchLocalSubscriptions()
        } else {
            signal = self.fetchSubscriptions()
        }
        streamListOfCategory                = [:]
        streamListOfCategory[uncategorized] = []
        state = .Fetching
        observer.sendNext(.StartLoading)
        return signal.map { (table: [FeedlyKit.Category: [Stream]]) -> Void in
                self.state = .Normal
                self.observer.sendNext(.CompleteLoading)
                return
            }.mapError { (error: NSError) in
                CloudAPIClient.handleError(error: error)
                self.state = .Error
                self.observer.sendNext(.FailToLoad(error))
                return error
        }
    }

    public func fetchLocalSubscriptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        streamListOfCategory = [:]
        streamListOfCategory[uncategorized] = []
        return SignalProducer { (_observer, disposable) in
            for category in Category.findAll() {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            for subscription in Subscription.findAll() {
                self.addSubscription(subscription)
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

    public func fetchSubscriptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        let signal: SignalProducer<[FeedlyKit.Category], NSError> = apiClient.fetchCategories()
        return signal.map { (categories: [FeedlyKit.Category]) -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> in
            for category in categories {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            return self.apiClient.fetchSubscriptions().map { subscriptions in
                for subscription in subscriptions {
                    self.addSubscription(subscription)
                }
                return self.streamListOfCategory
            }
        }.flatten(.Merge)
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
            if !CloudAPIClient.isLoggedIn {
                SubscriptionStore.create(subscription)
                self.addSubscription(subscription)
                self.state = .Normal
                self.observer.sendNext(.Create(subscription))
                _observer.sendNext(subscription)
                _observer.sendCompleted()
            } else {
                self.apiClient.subscribeTo(subscription) { response in
                    if let e = response.result.error {
                        CloudAPIClient.handleError(error: e)
                        self.state = .Error
                        self.observer.sendNext(.FailToUpdate(e))
                        _observer.sendFailed(CloudAPIClient.sharedInstance.buildError(e, response: response.response))
                    } else {
                        if self.useCache {
                            SubscriptionStore.create(subscription)
                        }
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
            if !CloudAPIClient.isLoggedIn {
                SubscriptionStore.remove(subscription)
                self.removeSubscription(subscription)
                self.state = .Normal
                self.observer.sendNext(.Remove(subscription))
                return
            }
            self.apiClient.unsubscribeTo(subscription.id, completionHandler: { response in
                if let e = response.result.error {
                    self.state = .Error
                    self.observer.sendNext(.FailToUpdate(e))
                } else {
                    if self.useCache {
                        SubscriptionStore.remove(subscription)
                    }
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
        fetchLocalSubscriptions()
        return result
    }
}
