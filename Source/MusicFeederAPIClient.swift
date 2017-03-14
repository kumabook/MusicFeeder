//
//  MusicFeederAPIClient.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/13/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveSwift
import Alamofire
import SwiftyJSON
import Breit

func urlEncode(_ string: String) -> String {
    return string.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
}

public struct AccessToken: ResponseObjectSerializable {
    public var accessToken: String
    public var tokenType:   String
    public var createdAt:   Int64
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    init(json: JSON) {
        self.accessToken = json["access_token"].stringValue
        self.tokenType   = json["token_type"].stringValue
        self.createdAt   = json["created_at"].int64Value
    }
}

struct CreateProfileAPI: API {
    var email:      String
    var password:   String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/profile" }
    var method:     Alamofire.HTTPMethod { return .put }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return try URLEncoding.default.encode(req, with: ["email": email, "password": password, "password_confirmation": password])
    }
}

struct FetchAccessTokenAPI: API {
    var email:        String
    var password:     String
    var clientId:     String
    var clientSecret: String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/oauth/token" }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        let params = ["grant_type": "password",
                       "client_id": clientId,
                   "client_secret": clientSecret,
                           "email": email,
                        "password": password]
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return try URLEncoding.default.encode(req, with: params)
    }
}

struct FetchTopicsAPI: API {
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics" }
    var method:     Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return req
    }
}

struct UpdateTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.HTTPMethod { return .put }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return req
    }
}

struct DeleteTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.HTTPMethod { return .delete }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return req
    }
}

struct FetchEnclosureAPI<T: Enclosure>: API {
    var enclosureId: String
    var url:         String {
        return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/\(T.resourceName)/\(enclosureId)"
    }
    var method:      Alamofire.HTTPMethod {
        return .get
    }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return req
    }
}

struct FetchEnclosuresAPI<T: Enclosure>: API {
    var enclosureIds: [String]
    var url:          String {
        return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/\(T.resourceName)/.mget"
    }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: enclosureIds, options: [])
        req.httpMethod = method.rawValue
        return req
    }
}

struct EnclosureMarkerAPI<T: Enclosure>: API {
    enum Action: String {
        case Like   = "markAsLiked"
        case Unlike = "markAsUnliked"
    }
    var items: [T]
    var action: Action

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/markers" }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        let params: [String: Any] = ["type": T.resourceName as AnyObject,
                                   "action": action.rawValue as AnyObject,
                                T.idListKey: self.tracks.map { $0.id }]
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return try URLEncoding.default.encode(req, with: params)
    }
}

public protocol ParameterEncodable {
    func toParameters() -> [String: Any]
}
/*
public extension Alamofire.ParameterEncoding {
    func encode(_ request: URLRequest, with: ParameterEncodable?) -> (URLRequest, NSError?) {
        return encode(request, with: with?.toParameters())
    }
}*/

open class PaginationParams: FeedlyKit.PaginationParams, ParameterEncodable {
    open var olderThan:    Int64?
    public override init() {}
    open override func toParameters() -> [String : Any] {
        var params: [String:Any] = [:]
        if let _count        = count        { params["count"]        = _count }
        if let _ranked       = ranked       { params["ranked"]       = _ranked }
        if let _unreadOnly   = unreadOnly   { params["unreadOnly"]   = _unreadOnly ? "true" : "false" }
        if let _newerThan    = newerThan    { params["newerThan"]    = NSNumber(value: _newerThan) }
        if let _olderThan    = olderThan    { params["olderThan"]    = NSNumber(value: _olderThan as Int64) }
        if let _continuation = continuation { params["continuation"] = _continuation }
        return params
    }
}

struct FetchTracksOfStreamAPI: API {
    var streamId:  String
    var params:    MusicFeeder.PaginationParams
    var url:       String { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/streams/\(urlEncode(streamId))/tracks/contents" }
    var method:     Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method.rawValue
        return try URLEncoding.default.encode(req, with: params.toParameters())
    }
}

open class PaginatedTrackCollection: ResponseObjectSerializable, PaginatedCollection {
    open let id:           String
    open let updated:      Int64?
    open let continuation: String?
    open let title:        String?
    open let direction:    String?
    open let alternate:    Link?
    open let items:        [Track]
    required public init?(response: HTTPURLResponse, representation: Any) {
        let json     = JSON(representation)
        id           = json["id"].stringValue
        updated      = json["updated"].int64
        continuation = json["continuation"].string
        title        = json["title"].string
        direction    = json["direction"].string
        alternate    = json["alternate"].isEmpty ? nil : Link(json: json["alternate"])
        items        = json["items"].arrayValue.map( {Track(json: $0)} )
    }
}

extension CloudAPIClient {
    public func createProfile(_ email: String, password: String) -> SignalProducer<Profile, NSError> {
        let route = Router.api(CreateProfileAPI(email: email, password: password))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<Profile>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let profile = r.result.value {
                    observer.send(value: profile)
                    observer.sendCompleted()
                }
            }
            disposable.add({ req.cancel() })
        }
    }

    public func fetchAccessToken(_ email: String, password: String, clientId: String, clientSecret: String) -> SignalProducer<AccessToken, NSError> {
        let route = Router.api(FetchAccessTokenAPI(email: email, password: password, clientId: clientId, clientSecret: clientSecret))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<AccessToken>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let accessToken = r.result.value {
                    observer.send(value: accessToken)
                    observer.sendCompleted()
                }
            }
            disposable.add({ req.cancel() })
        }
    }

    public func fetchTopics() -> SignalProducer<[Topic], NSError> {
        let route = Router.api(FetchTopicsAPI())
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseCollection() { (r: DataResponse<[Topic]>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let topics = r.result.value {
                    observer.send(value: topics)
                    observer.sendCompleted()
                }
            }
            disposable.add({ req.cancel() })
        }
    }

    public func updateTopic(_ topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.api(UpdateTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DataResponse<Void>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let _ = r.result.value {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.add({ req.cancel() })
        }
    }

    public func deleteTopic(_ topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.api(DeleteTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DataResponse<Void>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let _ = r.result.value {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.add() { req.cancel() }
        }
    }

    public func fetchEnclosure<T: Enclosure>(_ enclosureId: String) -> SignalProducer<T, NSError> {
        let route = Router.api(FetchEnclosureAPI<T>(enclosureId: enclosureId))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<T>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let enclosure = r.result.value {
                    observer.send(value: enclosure)
                    observer.sendCompleted()
                }
            }
            disposable.add() { req.cancel() }
        }
    }

    public func fetchEnclosures<T: Enclosure>(_ enclosureIds: [String]) -> SignalProducer<[T], NSError> {
        let route = Router.api(FetchEnclosuresAPI<T>(enclosureIds: enclosureIds))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseCollection() { (r: DataResponse<[T]>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let enclosures = r.result.value {
                    observer.send(value: enclosures)
                    observer.sendCompleted()
                }
            }
            disposable.add() { req.cancel() }
        }
    }

    public func fetchTracksOf(_ streamId: String, paginationParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedTrackCollection, NSError> {
        let route = Router.api(FetchTracksOfStreamAPI(streamId: streamId, params: paginationParams))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<PaginatedTrackCollection>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let tracks = r.result.value {
                    observer.send(value: tracks)
                    observer.sendCompleted()
                }
            }
            disposable.add() { req.cancel() }
        }
    }

    fileprivate func markTracksAs(_ tracks: [Track], action: TrackMarkerAPI.Action) -> SignalProducer<Void, NSError> {
        let route = Router.api(TrackMarkerAPI(tracks: tracks, action: action))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DataResponse<Void>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.add() { req.cancel() }
        }
    }

    public func markTracksAsLiked(_ tracks: [Track]) -> SignalProducer<Void, NSError> {
        return markTracksAs(tracks, action: TrackMarkerAPI.Action.Like)
    }

    public func markTracksAsUnliked(_ tracks: [Track]) -> SignalProducer<Void, NSError> {
        return markTracksAs(tracks, action: TrackMarkerAPI.Action.Unlike)
    }
}
