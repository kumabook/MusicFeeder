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

    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/profile" }
    var method:     Alamofire.HTTPMethod { return .put }
    func asURLRequest() throws -> URLRequest {
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: ["email": email, "password": password, "password_confirmation": password])
    }
}

struct EditProfileAPI: API {
    var url:    String  { return "\(CloudAPIClient.shared.target.baseUrl)/v3/profile/edit" }
    var method: Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

public struct EditProfileResponse: ResponseObjectSerializable {
    public var picturePutUrl: String
    public var pictureUrl:    String
    public var profile:       Profile
    public init?(response: HTTPURLResponse, representation: Any) {
        let json = JSON(representation)
        self.init(json: json)
    }

    init(json: JSON) {
        self.picturePutUrl = json["picture_put_url"].stringValue
        self.pictureUrl    = json["picture_url"].stringValue
        self.profile       = Profile(json: json)
    }

    public func uploadPicture(imageData: Data) -> SignalProducer<Void, NSError> {
        guard let url = URL(string: picturePutUrl) else { return SignalProducer(error: NSError(domain: "MusicFeeder", code: 0, userInfo: ["message":"invalid picture put url"]))}
        return SignalProducer { (observer, disposable) in
            let req: Alamofire.UploadRequest = Alamofire.upload(imageData, to: url, method: .put)
            req.response(completionHandler: {
                if let error = $0.error {
                    observer.send(error: error as NSError)
                } else {
                    observer.send(value: ())
                }
            })
            disposable.observeEnded {
                req.cancel()
            }
        }
    }
}

struct FetchAccessTokenAPI: API {
    var email:        String
    var password:     String
    var clientId:     String
    var clientSecret: String

    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/oauth/token" }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        let params = ["grant_type": "password",
                       "client_id": clientId,
                   "client_secret": clientSecret,
                           "email": email,
                        "password": password]
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: params)
    }
}

struct FetchTopicsAPI: API {
    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/topics" }
    var method:     Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

struct UpdateTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.HTTPMethod { return .put }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

struct DeleteTopicAPI: API {
    var topicId:    String
    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/topics/\(urlEncode(topicId))" }
    var method:     Alamofire.HTTPMethod { return .delete }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

struct FetchEnclosureAPI<T: Enclosure>: API {
    var enclosureId: String
    var url:         String {
        return "\(CloudAPIClient.shared.target.baseUrl)/v3/\(T.resourceName)/\(enclosureId)"
    }
    var method:      Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

struct FetchEnclosuresAPI<T: Enclosure>: API {
    var enclosureIds: [String]
    var url:          String {
        return "\(CloudAPIClient.shared.target.baseUrl)/v3/\(T.resourceName)/.mget"
    }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        var req = try URLRequest(url: URL(string: url)!, method: method)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: enclosureIds, options: [])
        return req
    }
}

public enum MarkerAction: String {
    case liked    = "markAsLiked"
    case unliked  = "markAsUnliked"
    case saved    = "markAsSaved"
    case unsaved  = "markAsUnsaved"
    case played   = "markAsPlayed"
    case read     = "markAsRead"
    case unread   = "markAsUnread"
}

struct EntryMarkerAPI: API {
    var items: [Entry]
    var action: MarkerAction

    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/markers" }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        let params: [String: Any] = ["type"    : "entries",
                                     "action"  : action.rawValue as AnyObject,
                                     "entryIds": self.items.map { $0.id }]
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: params)
    }
}

struct EnclosureMarkerAPI<T: Enclosure>: API {
    var items: [T]
    var action: MarkerAction

    var url:        String           { return "\(CloudAPIClient.shared.target.baseUrl)/v3/markers" }
    var method:     Alamofire.HTTPMethod { return .post }
    func asURLRequest() throws -> URLRequest {
        let params: [String: Any] = ["type": T.resourceName as AnyObject,
                                   "action": action.rawValue as AnyObject,
                                T.idListKey: self.items.map { $0.id }]
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: params)
    }
}

typealias TrackMarkerAPI = EnclosureMarkerAPI<Track>

struct FetchWallAPI: API {
    var id:  String
    var url: String { return "\(CloudAPIClient.shared.target.baseUrl)/v3/walls/\(urlEncode(id))" }
    var method: Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: URL(string: url)!, method: method)
    }
}

public protocol ParameterEncodable {
    func toParameters() -> [String: Any]
}

open class PaginationParams: FeedlyKit.PaginationParams, ParameterEncodable {
    open var olderThan: Int64?
    public override init() {}
    open override func toParameters() -> [String : Any] {
        var params: [String:Any] = [:]
        if let count        = count        { params["count"]        = count }
        if let ranked       = ranked       { params["ranked"]       = ranked }
        if let unreadOnly   = unreadOnly   { params["unreadOnly"]   = unreadOnly ? "true" : "false" }
        if let newerThan    = newerThan    { params["newerThan"]    = NSNumber(value: newerThan) }
        if let olderThan    = olderThan    { params["olderThan"]    = NSNumber(value: olderThan as Int64) }
        if let continuation = continuation { params["continuation"] = continuation }
        return params
    }
}

open class MixParams: FeedlyKit.MixParams {
    open var type:      MixType = .hot
    open var olderThan: Int64?
    public override init() {}
    open override func toParameters() -> [String : Any] {
        var params: [String:Any] = [:]
        if let count        = count        { params["count"]        = count }
        if let unreadOnly   = unreadOnly   { params["unreadOnly"]   = unreadOnly ? "true" : "false" }
        if let newerThan    = newerThan    { params["newerThan"]    = NSNumber(value: newerThan) }
        if let olderThan    = olderThan    { params["olderThan"]    = NSNumber(value: olderThan as Int64) }
        if let continuation = continuation { params["continuation"] = continuation }
        params["type"] = type.rawValue
        return params
    }
}

public enum MixPeriod: String {
    case `default` = "default"
    case daily     = "daily"
    case weekly    = "weekly"
    case monthly   = "monthly"

    public var newerThan: Int64? {
        switch self {
        case .daily:
            return Int64(Date(timeIntervalSinceNow: -1 * 24 * 60 * 60).timeIntervalSince1970 * 1000)
        case .weekly:
            return Int64(Date(timeIntervalSinceNow: -7 * 24 * 60 * 60).timeIntervalSince1970 * 1000)
        case .monthly:
            return Int64(Date(timeIntervalSinceNow: -30 * 24 * 60 * 60).timeIntervalSince1970 * 1000)
        default:
            return nil
        }
    }
}

public enum MixType: String {
    case hot      = "hot"
    case popular  = "popular"
    case featured = "featured"
}

struct FetchEnclosuresOfStreamAPI<T: Enclosure>: API {
    private let baseUrl = CloudAPIClient.shared.target.baseUrl
    var streamId:  String
    var params:    FeedlyKit.PaginationParams
    var url:       String { return "\(baseUrl)/v3/streams/\(urlEncode(streamId))/\(T.resourceName)/contents" }
    var method:    Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: params.toParameters())
    }
}

typealias FetchTracksOfStreamAPI = FetchEnclosuresOfStreamAPI<Track>
typealias FetchAlbumsOfStreamAPI = FetchEnclosuresOfStreamAPI<Album>
typealias FetchPlaylistsOfStreamAPI = FetchEnclosuresOfStreamAPI<ServicePlaylist>

struct FetchEnclosuresOfMixAPI<T: Enclosure>: API {
    private let baseUrl = CloudAPIClient.shared.target.baseUrl
    var streamId:  String
    var params:    FeedlyKit.PaginationParams
    var url:       String { return "\(baseUrl)/v3/mixes/\(urlEncode(streamId))/\(T.resourceName)/contents" }
    var method:    Alamofire.HTTPMethod { return .get }
    func asURLRequest() throws -> URLRequest {
        let req = try URLRequest(url: URL(string: url)!, method: method)
        return try URLEncoding.default.encode(req, with: params.toParameters())
    }
}

open class PaginatedEnclosureCollection<T: Enclosure>: ResponseObjectSerializable, PaginatedCollection {
    open let id:           String
    open let updated:      Int64?
    open let continuation: String?
    open let title:        String?
    open let direction:    String?
    open let alternate:    Link?
    open let items:        [T]
    required public convenience init?(response: HTTPURLResponse, representation: Any) {
        let json     = JSON(representation)
        self.init(json: json)
    }
    public init(json: JSON) {
        id           = json["id"].stringValue
        updated      = json["updated"].int64
        continuation = json["continuation"].string
        title        = json["title"].string
        direction    = json["direction"].string
        alternate    = json["alternate"].isEmpty ? nil : Link(json: json["alternate"])
        items        = json["items"].arrayValue.map( {T(json: $0)} )
    }
}

public typealias PaginatedTrackCollection = PaginatedEnclosureCollection<Track>
public typealias PaginatedAlbumCollection = PaginatedEnclosureCollection<Album>
public typealias PaginatedPlaylistCollection = PaginatedEnclosureCollection<ServicePlaylist>

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
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func editProfile() -> SignalProducer<EditProfileResponse, NSError> {
        let route = Router.api(EditProfileAPI())
        return SignalProducer{ (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<EditProfileResponse>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let profile = r.result.value {
                    observer.send(value: profile)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
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
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func fetchTopics(useCache: Bool = false) -> SignalProducer<[Topic], NSError> {
        let route = Router.api(FetchTopicsAPI())
        return SignalProducer { (observer, disposable) in
            var urlRequest = try! route.asURLRequest()
            if useCache {
                if let url = urlRequest.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let topics = JSON(parseJSON: json).arrayValue.map({ Topic(json: $0) })
                    observer.send(value: topics)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).validate().responseJSON() { response -> Void in
                if let e = response.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: response.response))
                } else if let value = response.result.value {
                    let json = JSON(json: value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    let topics = json.arrayValue.map() { Topic(json: $0) }
                    observer.send(value: topics)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func updateTopic(_ topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.api(UpdateTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DefaultDataResponse) -> Void in
                if let e = r.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded({ req.cancel() })
        }
    }

    public func deleteTopic(_ topic: Topic) -> SignalProducer<Void, NSError> {
        let route = Router.api(DeleteTopicAPI(topicId: topic.id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DefaultDataResponse) -> Void in
                if let e = r.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchEnclosure<T: Enclosure>(_ id: String) -> SignalProducer<T, NSError> {
        let route = Router.api(FetchEnclosureAPI<T>(enclosureId: id))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseObject() { (r: DataResponse<T>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let enclosure = r.result.value {
                    observer.send(value: enclosure)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchTrack(_ id: String) -> SignalProducer<Track, NSError> {
        return fetchEnclosure(id)
    }
    public func fetchAlbum(_ id: String) -> SignalProducer<Album, NSError> {
        return fetchEnclosure(id)
    }
    public func fetchPlaylist(_ id: String) -> SignalProducer<ServicePlaylist, NSError> {
        return fetchEnclosure(id)
    }

    public func fetchEnclosures<T: Enclosure>(_ ids: [String]) -> SignalProducer<[T], NSError> {
        let route = Router.api(FetchEnclosuresAPI<T>(enclosureIds: ids))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().responseCollection() { (r: DataResponse<[T]>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let enclosures = r.result.value {
                    observer.send(value: enclosures)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchTracks(_ ids: [String]) -> SignalProducer<[Track], NSError> {
        return fetchEnclosures(ids)
    }
    public func fetchAlbums(_ ids: [String]) -> SignalProducer<[Album], NSError> {
        return fetchEnclosures(ids)
    }
    public func fetchPlaylists(_ ids: [String]) -> SignalProducer<[ServicePlaylist], NSError> {
        return fetchEnclosures(ids)
    }

    public func fetchEnclosuresOf<T: Enclosure>(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedEnclosureCollection<T>, NSError> {
        let route = Router.api(FetchEnclosuresOfStreamAPI<T>(streamId: streamId, params: paginationParams))
        return SignalProducer { (observer, disposable) in
            if useCache {
                if let url = route.urlRequest?.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let v = PaginatedEnclosureCollection<T>(json: JSON(parseJSON: json))
                    observer.send(value: v)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).validate().responseJSON() { r in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let value = r.result.value {
                    let json = JSON(json: value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    observer.send(value: PaginatedEnclosureCollection<T>(json: json))
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchEnclosureMixOf<T: Enclosure>(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedEnclosureCollection<T>, NSError> {
        let route = Router.api(FetchEnclosuresOfMixAPI<T>(streamId: streamId, params: paginationParams))
        return SignalProducer { (observer, disposable) in
            if useCache {
                if let url = route.urlRequest?.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let v = PaginatedEnclosureCollection<T>(json: JSON(parseJSON: json))
                    observer.send(value: v)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(route).validate().responseJSON() { r in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let value = r.result.value {
                    let json = JSON(json: value)
                    if let url = route.urlRequest?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    observer.send(value: PaginatedEnclosureCollection(json: json))
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func fetchTracksOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedTrackCollection, NSError> {
        return fetchEnclosuresOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func fetchAlbumsOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedAlbumCollection, NSError> {
        return fetchEnclosuresOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func fetchPlaylistsOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedPlaylistCollection, NSError> {
        return fetchEnclosuresOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func fetchTrackMixOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedTrackCollection, NSError> {
        return fetchEnclosureMixOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func fetchAlbumMixOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedAlbumCollection, NSError> {
        return fetchEnclosureMixOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func fetchPlaylistMixOf(_ streamId: String, paginationParams: FeedlyKit.PaginationParams, useCache: Bool = false) -> SignalProducer<PaginatedPlaylistCollection, NSError> {
        return fetchEnclosureMixOf(streamId, paginationParams: paginationParams, useCache: useCache)
    }

    public func markEntriesAs(_ action: MarkerAction, items: [Entry]) -> SignalProducer<Void, NSError> {
        let route = Router.api(EntryMarkerAPI(items: items, action: action))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DefaultDataResponse) -> Void in
                if let e = r.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    internal func markEnclosuresAs<T: Enclosure>(_ action: MarkerAction, items: [T]) -> SignalProducer<Void, NSError> {
        let route = Router.api(EnclosureMarkerAPI<T>(items: items, action: action))
        return SignalProducer { (observer, disposable) in
            let req = self.manager.request(route).validate().response() { (r: DefaultDataResponse) -> Void in
                if let e = r.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else {
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }

    public func markTracksAs(_ action: MarkerAction, items: [Track]) -> SignalProducer<Void, NSError> {
        return markEnclosuresAs(action, items: items)
    }
    public func markAlbumsAs(_ action: MarkerAction, items: [Album]) -> SignalProducer<Void, NSError> {
        return markEnclosuresAs(action, items: items)
    }
    public func markPlaylistsAs(_ action: MarkerAction, items: [ServicePlaylist]) -> SignalProducer<Void, NSError> {
        return markEnclosuresAs(action, items: items)
    }
    public func fetchWall(_ id: String, useCache: Bool = false) -> SignalProducer<Wall, NSError> {
        let route = Router.api(FetchWallAPI(id: id))
        return SignalProducer { (observer, disposable) in
            var urlRequest = try! route.asURLRequest()
            if useCache {
                if let url = urlRequest.url?.absoluteString, let json = JSONCache.shared.get(forKey: url) {
                    let wall = Wall(json: JSON(parseJSON: json))
                    observer.send(value: wall)
                } else {
                    observer.send(error: NSError(domain: "music_feeder", code: -1, userInfo: ["message": "no cache"]))
                }
                return
            }
            let req = self.manager.request(urlRequest).validate().responseJSON() { (r: DataResponse<Any>) -> Void in
                if let e = r.result.error {
                    observer.send(error: self.buildError(error: e as NSError, response: r.response))
                } else if let value = r.result.value {
                    let json = JSON(value)
                    if let url = r.request?.url?.absoluteString {
                        if let str = json.rawString() {
                            let _ = try? JSONCache.shared.add(str, forKey: url)
                        }
                    }
                    let wall = Wall(json: json)
                    observer.send(value: wall)
                    observer.sendCompleted()
                }
            }
            disposable.observeEnded() { req.cancel() }
        }
    }
}
