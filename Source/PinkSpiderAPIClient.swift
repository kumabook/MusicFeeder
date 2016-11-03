//
//  MusicFavAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import ReactiveSwift
import Result
import Alamofire
import FeedlyKit

open class PinkSpiderAPIClient {
    static let baseUrl   = "http://pink-spider.herokuapp.com"
    open static var sharedInstance = PinkSpiderAPIClient()
    static var sharedManager: Alamofire.SessionManager! = Alamofire.SessionManager()

    open func playlistify(_ targetUrl: NSURL, errorOnFailure: Bool) -> SignalProducer<Playlist, NSError> {
        return SignalProducer { (observer, disposable) in
            let url = String(format: "%@/playlistify", PinkSpiderAPIClient.baseUrl)
            let request = PinkSpiderAPIClient.sharedManager.request(url, parameters: ["url": targetUrl], encoding: URLEncoding.default)
            .responseJSON(options: JSONSerialization.ReadingOptions()) { response in
                if let e = response.result.error {
                    if errorOnFailure { observer.send(error: e as NSError) }
                    else              { observer.sendCompleted() }
                } else {
                    observer.send(value: Playlist(json: JSON(response.result.value!)))
                    observer.sendCompleted()
                }
            }
            disposable.add() {
                request.cancel()
            }
        }
    }
}
