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
    func invalidate()
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

    public func invalidate() {
    }

    public func markAsLiked() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.liked)
    }

    public func markAsUnliked() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.unliked)
    }

    public func markAsSaved() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.saved)
    }

    public func markAsUnsaved() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.unsaved)
    }

    public func markAsOpened() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.opened)
    }

    public func markAsUnopened() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.unopened)
    }

    internal func markAs(action: MarkerAction) -> SignalProducer<Self, NSError> {
        return CloudAPIClient.sharedInstance.markEnclosuresAs(action, items: [self])
                                            .flatMap(.concat) { () ->  SignalProducer<Self, NSError> in
            self.invalidate()
            return self.fetch()
        }
    }

    public func fetch() -> SignalProducer<Self, NSError> {
        return CloudAPIClient.sharedInstance.fetchEnclosure(id)
    }
}
