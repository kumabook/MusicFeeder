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
    private var disposable:          Disposable?
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

    public class func sampleSubscriptions() -> [Subscription] {
        return [Subscription(id: "feed/http://spincoaster.com/feed",
                          title: "Spincoaster (sample)",
                     categories: []),
                Subscription(id: "feed/http://matome.naver.jp/feed/topic/1Hinb",
                          title: "Naver matome (sample)",
                     categories: [])]
    }

    public class func defaultStream() -> Stream {
        if let profile = CloudAPIClient.profile {
            return FeedlyKit.Category.All(profile.id)
        } else {
            return StreamListLoader.sampleSubscriptions()[0]
        }
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

    public func dispose() {
        disposable?.dispose()
        disposable = nil
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

    public func refresh() {
        if !CloudAPIClient.isLoggedIn {
            sink.put(.Next(Box(.StartLoading)))
            if streamListOfCategory[uncategorized]!.count == 0 {
                streamListOfCategory[uncategorized]?.extend(StreamListLoader.sampleSubscriptions() as [Stream])
            }
            self.sink.put(.Next(Box(.CompleteLoading)))
            return
        }
        streamListOfCategory                = [:]
        streamListOfCategory[uncategorized] = []
        state = .Fetching
        sink.put(.Next(Box(.StartLoading)))
        disposable?.dispose()
        disposable = self.fetchSubscriptions() |> startOn(UIScheduler()) |> start(
            next: { dic in
                self.sink.put(.Next(Box(.StartLoading)))
            }, error: { error in
                CloudAPIClient.handleError(error: error)
                self.state = .Error
                self.sink.put(.Next(Box(.FailToLoad(error))))
            }, completed: {
                self.state = .Normal
                self.sink.put(.Next(Box(.CompleteLoading)))
        })
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
        }
        return nil
    }

    public func subscribeTo(subscribable: Subscribable, categories: [FeedlyKit.Category]) -> SignalProducer<Subscription, NSError> {
        let s = subscribable.toSubscription()
        var c = categories
        c.extend(s.categories)
        return subscribeTo(Subscription(id: s.id, title: s.title, categories: c))
    }

    public func subscribeTo(subscription: Subscription) -> SignalProducer<Subscription, NSError> {
        return SignalProducer<Subscription, NSError> { (sink, disposable) in
            if !CloudAPIClient.isLoggedIn {
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
