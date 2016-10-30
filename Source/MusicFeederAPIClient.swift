//
//  MusicFeederAPIClient.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 3/13/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit
import ReactiveCocoa
import Alamofire
import SwiftyJSON

func urlEncode(string: String) -> String {
    return string.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
}

public struct AccessToken: ResponseObjectSerializable {
    public var accessToken: String
    public var tokenType:   String
    public var createdAt:   Int64
    public init?(response: NSHTTPURLResponse, representation: AnyObject) {
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
    var method:     Alamofire.Method { return .PUT }
    var URLRequest: NSMutableURLRequest {
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: ["email": email, "password": password, "password_confirmation": password]).0
    }
}

struct FetchAccessTokenAPI: API {
    var email:        String
    var password:     String
    var clientId:     String
    var clientSecret: String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/oauth/token" }
    var method:     Alamofire.Method { return .POST }
    var URLRequest: NSMutableURLRequest {
        let params = ["grant_type": "password",
                       "client_id": clientId,
                   "client_secret": clientSecret,
                           "email": email,
                        "password": password]
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: params).0
    }
}

struct FetchTopicsAPI: API {
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics" }
    var method:     Alamofire.Method { return .GET }
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return req
    }
}

struct UpdateTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.Method { return .PUT }
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return req
    }
}

struct DeleteTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.Method { return .DELETE }
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return req
    }
}

struct FetchTrackAPI: API {
    var trackId: String

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/tracks/\(trackId)" }
    var method:     Alamofire.Method { return .GET }
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return req
    }
}

struct FetchTracksAPI: API {
    var trackIds: [String]

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/tracks/.mget" }
    var method:     Alamofire.Method { return .POST }
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(trackIds, options: [])
        req.HTTPMethod = method.rawValue
        return req
    }
}

struct TrackMarkerAPI: API {
    enum Action: String {
        case Like   = "markAsLiked"
        case Unlike = "markAsUnliked"
    }
    var tracks: [Track]
    var action: Action

    var url:        String           { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/markers" }
    var method:     Alamofire.Method { return .POST }
    var URLRequest: NSMutableURLRequest {
        let params: [String: AnyObject] = ["type": "tracks",
                                         "action": action.rawValue,
                                       "trackIds": self.tracks.map { $0.id }]
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: params).0
    }
}

public protocol ParameterEncodable {
    func toParameters() -> [String: AnyObject]
}

public extension Alamofire.ParameterEncoding {
    func encode(URLRequest: URLRequestConvertible, parameters: ParameterEncodable?) -> (NSMutableURLRequest, NSError?) {
        return encode(URLRequest, parameters: parameters?.toParameters())
    }
}

public class PaginationParams: FeedlyKit.PaginationParams, ParameterEncodable {
    public var olderThan:    Int64?
    public override init() {}
    public override func toParameters() -> [String : AnyObject] {
        var params: [String:AnyObject] = [:]
        if let _count        = count        { params["count"]        = _count }
        if let _ranked       = ranked       { params["ranked"]       = _ranked }
        if let _unreadOnly   = unreadOnly   { params["unreadOnly"]   = _unreadOnly ? "true" : "false" }
        if let _newerThan    = newerThan    { params["newerThan"]    = NSNumber(longLong: _newerThan) }
        if let _olderThan    = olderThan    { params["olderThan"]    = NSNumber(longLong: _olderThan) }
        if let _continuation = continuation { params["continuation"] = _continuation }
        return params
    }
}

struct FetchTracksOfStreamAPI: API {
    var streamId:  String
    var params:    MusicFeeder.PaginationParams
    var url:       String { return "\(CloudAPIClient.sharedInstance.target.baseUrl)/v3/streams/\(urlEncode(streamId))/tracks/contents" }
    var method:     Alamofire.Method { return .GET }
    var URLRequest: NSMutableURLRequest {
        let U = Alamofire.ParameterEncoding.URL
        let URL = NSURL(string: url)!
        let req = NSMutableURLRequest(URL: URL)
        req.HTTPMethod = method.rawValue
        return U.encode(req, parameters: params.toParameters()).0
    }
}

public class PaginatedTrackCollection: ResponseObjectSerializable, PaginatedCollection {
    public let id:           String
    public let updated:      Int64?
    public let continuation: String?
    public let title:        String?
    public let direction:    String?
    public let alternate:    Link?
    public let items:        [Track]
    required public init?(response: NSHTTPURLResponse, representation: AnyObject) {
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
    public func createProfile(email: String, password: String) -> SignalProducer<Profile, NSError> {
        let route = Router.Api(CreateProfileAPI(email: email, password: password))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<Profile, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let profile = r.result.value {
                    observer.sendNext(profile)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchAccessToken(email: String, password: String, clientId: String, clientSecret: String) -> SignalProducer<AccessToken, NSError> {
        let route = Router.Api(FetchAccessTokenAPI(email: email, password: password, clientId: clientId, clientSecret: clientSecret))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<AccessToken, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let accessToken = r.result.value {
                    observer.sendNext(accessToken)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchTopics() -> SignalProducer<[Topic], NSError> {
        let route = Router.Api(FetchTopicsAPI())
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseCollection() { (r: Response<[Topic], NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let topics = r.result.value {
                    observer.sendNext(topics)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func updateTopic(topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.Api(UpdateTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: Response<Void, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let _ = r.result.value {
                    observer.sendNext()
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func deleteTopic(topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.Api(DeleteTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: Response<Void, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let _ = r.result.value {
                    observer.sendNext()
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchTrack(trackId: String) -> SignalProducer<Track, NSError> {
        let route = Router.Api(FetchTrackAPI(trackId: trackId))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<Track, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let track = r.result.value {
                    observer.sendNext(track)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchTracks(trackIds: [String]) -> SignalProducer<[Track], NSError> {
        let route = Router.Api(FetchTracksAPI(trackIds: trackIds))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseCollection() { (r: Response<[Track], NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let tracks = r.result.value {
                    observer.sendNext(tracks)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func fetchTracksOf(streamId: String, paginationParams: MusicFeeder.PaginationParams) -> SignalProducer<PaginatedTrackCollection, NSError> {
        let route = Router.Api(FetchTracksOfStreamAPI(streamId: streamId, params: paginationParams))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: Response<PaginatedTrackCollection, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else if let tracks = r.result.value {
                    observer.sendNext(tracks)
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    private func markTracksAs(tracks: [Track], action: TrackMarkerAPI.Action) -> SignalProducer<Void, NSError> {
        let route = Router.Api(TrackMarkerAPI(tracks: tracks, action: action))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: Response<Void, NSError>) -> Void in
                if let e = r.result.error {
                    observer.sendFailed(self.buildError(e, response: r.response))
                } else {
                    observer.sendNext()
                    observer.sendCompleted()
                }
            }
            disposable.addDisposable({ req.cancel() })
        }
    }

    public func markTracksAsLiked(tracks: [Track]) -> SignalProducer<Void, NSError> {
        return markTracksAs(tracks, action: TrackMarkerAPI.Action.Like)
    }

    public func markTracksAsUnliked(tracks: [Track]) -> SignalProducer<Void, NSError> {
        return markTracksAs(tracks, action: TrackMarkerAPI.Action.Unlike)
    }
}