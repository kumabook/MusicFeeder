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

public protocol Enclosure: class, ResponseObjectSerializable, ResponseCollectionSerializable {
    static var resourceName: String { get }
    static var idListKey:    String { get }
    init?(urlString: String)
    init(json: JSON)
    var id: String { get }
    func invalidate()
    func sendToSharedPipe()
    func updateMarkProperties(item: Self)
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

    public func markAsPlayed() -> SignalProducer<Self, NSError> {
        return markAs(action: MarkerAction.played)
    }

    internal func markAs(action: MarkerAction) -> SignalProducer<Self, NSError> {
        return CloudAPIClient.shared.markEnclosuresAs(action, items: [self])
                                            .flatMap(.concat) { () ->  SignalProducer<Self, NSError> in
            self.invalidate()
            return self.fetch().map {
                self.updateMarkProperties(item: $0)
                $0.sendToSharedPipe()
                return $0
            }
        }
    }

    public func fetch() -> SignalProducer<Self, NSError> {
        return CloudAPIClient.shared.fetchEnclosure(id)
    }
}
