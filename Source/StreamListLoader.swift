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
import Box

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
        case FailToLoad(NSError)
        case StartUpdating
        case FailToUpdate(NSError)
        case RemoveAt(Int, Subscription, FeedlyKit.Category)
    }

    var apiClient:            CloudAPIClient { return CloudAPIClient.sharedInstance }
    public var state:                State
    public var signal:               Signal<Event, NSError>
    private var sink:                SinkOf<ReactiveCocoa.Event<Event, NSError>>
    public var streamListOfCategory: [FeedlyKit.Category: [Stream]]
    public var uncategorized:        FeedlyKit.Category
    public var categories: [FeedlyKit.Category] {
        return streamListOfCategory.keys.array.sorted({ (first, second) -> Bool in
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
        sink                 = pipe.1
        uncategorized        = FeedlyKit.Category.Uncategorized()
        if let userId = CloudAPIClient.profile?.id {
            uncategorized = FeedlyKit.Category.Uncategorized(userId)
        }
        streamListOfCategory[uncategorized] = []
    }

    deinit {
        dispose()
    }

    public func dispose() {}

    public func getStream(#id: String) -> Stream? {
        return flatMap(streamListOfCategory.values) { $0 }.filter { $0.streamId == id }.first
    }

    private func addSubscription(subscription: Subscription) {
        var categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            if find(streamListOfCategory[category]!, subscription) == nil {
                streamListOfCategory[category]!.append(subscription)
            }
        }
    }

    private func removeSubscription(subscription: Subscription) {
        var categories = subscription.categories.count > 0 ? subscription.categories : [uncategorized]
        for category in categories {
            let index = find(self.streamListOfCategory[category]!, subscription)
            if let i = index {
                streamListOfCategory[category]!.removeAtIndex(i)
            }
        }
    }

    public func refresh() -> SignalProducer<Void, NSError> {
        var signal: SignalProducer<[FeedlyKit.Category: [Stream]], NSError>
        if !CloudAPIClient.isLoggedIn {
            signal = self.fetchLocalSubscrptions()
        } else {
            signal = self.fetchSubscriptions()
        }
        streamListOfCategory                = [:]
        streamListOfCategory[uncategorized] = []
        state = .Fetching
        sink.put(.Next(Box(.StartLoading)))
        return signal |> map { (table: [FeedlyKit.Category: [Stream]]) -> Void in
            self.state = .Normal
            self.sink.put(.Next(Box(.CompleteLoading)))
            return
            } |> mapError { (error: NSError) in
                CloudAPIClient.handleError(error: error)
                self.state = .Error
                self.sink.put(.Next(Box(.FailToLoad(error))))
                return error
        }
    }

    public func fetchLocalSubscrptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        return SignalProducer { (sink, disposable) in
            for category in CategoryStore.findAll() {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            for subscription in SubscriptionStore.findAll() {
                self.addSubscription(subscription)
            }
            for key in self.streamListOfCategory.keys.array {
                if self.streamListOfCategory[key]!.isEmpty {
                    if key != self.uncategorized {
                        self.streamListOfCategory.removeValueForKey(key)
                    }
                }
            }
            sink.put(.Next(Box(self.streamListOfCategory)))
            sink.put(.Completed)
            return
        }
    }

    public func fetchSubscriptions() -> SignalProducer<[FeedlyKit.Category: [Stream]], NSError> {
        return apiClient.fetchCategories() |> map { categories in
            for category in categories {
                self.streamListOfCategory[category] = [] as [Stream]
            }
            return self.apiClient.fetchSubscriptions() |> map { subscriptions in
                for subscription in subscriptions {
                    self.addSubscription(subscription)
                }
                return self.streamListOfCategory
            }
        } |> flatten(.Merge)
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
        return SignalProducer<Subscription, NSError> { (sink, disposable) in
            if !CloudAPIClient.isLoggedIn {
                SubscriptionStore.create(subscription)
                self.addSubscription(subscription)
                self.state = .Normal
                sink.put(.Next(Box(subscription)))
                sink.put(.Completed)
            } else {
                CloudAPIClient.sharedInstance.subscribeTo(subscription) { (req, res, error) -> Void in
                    if let e = error {
                        CloudAPIClient.handleError(error: e)
                        self.state = .Error
                        self.sink.put(.Next(Box(.FailToUpdate(e))))
                        sink.put(.Error(Box(e)))
                    } else {
                        self.addSubscription(subscription)
                        self.state = .Normal
                        sink.put(.Next(Box(subscription)))
                        sink.put(.Completed)
                    }
                }
            }
        }
    }

    public func unsubscribeTo(subscription: Subscription, index: Int, category: FeedlyKit.Category) {
        state = .Updating
        self.sink.put(.Next(Box(.StartUpdating)))
        if !CloudAPIClient.isLoggedIn {
            SubscriptionStore.remove(subscription)
            self.removeSubscription(subscription)
            self.state = .Normal
            self.sink.put(.Next(Box(.RemoveAt(index, subscription, category))))
            return
        }
        apiClient.unsubscribeTo(subscription.id, completionHandler: { (req, res, error) -> Void in
            if let e = error {
                self.state = .Error
                self.sink.put(.Next(Box(.FailToUpdate(e))))
            } else {
                self.removeSubscription(subscription)
                self.state = .Normal
                self.sink.put(.Next(Box(.RemoveAt(index, subscription, category))))
            }
        })
    }
}
