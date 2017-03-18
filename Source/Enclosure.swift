//
//  Enclosure.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/14.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import SwiftyJSON
import FeedlyKit
import ReactiveSwift

public protocol Enclosure: ResponseObjectSerializable, ResponseCollectionSerializable {
    static var resourceName: String { get }
    static var idListKey:    String { get }
    init?(urlString: String)
    init(json: JSON)
    var id: String { get }
    static func parseURI(uri: String) -> [String: String]
}

public extension Enclosure {
    static func parseURI(uri: String) -> [String: String] {
        let components: URLComponents? = URLComponents(string: uri.replace("+", withString: "%20"))
        var dic: [String:String] = [:]
        components?.queryItems?.forEach {
            dic[$0.name] = $0.value
        }
        dic["type"] = components?.path.components(separatedBy: "/").get(1) ?? ""
        return dic
    }

    public func markAsLiked() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Like)
    }

    public func markAsUnliked() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Unlike)
    }

    public func markAsSaved() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Save)
    }

    public func markAsUnsaved() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Unsave)
    }

    public func markAsOpened() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Open)
    }

    public func markAsUnopened() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.Unopen)
    }

    internal func markAs(action: MarkerAction) -> SignalProducer<Self, NSError> {
        return CloudAPIClient.sharedInstance.markEnclosuresAs([self], action: action).flatMap(.concat) {
            self.fetch()
        }
    }

    public func fetch() -> SignalProducer<Self, NSError> {
        return CloudAPIClient.sharedInstance.fetchEnclosure(id)
    }
}
