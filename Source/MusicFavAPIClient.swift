//
//  MusicFavAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import SwiftyJSON
import ReactiveCocoa
import Result
import Box
import Alamofire
import FeedlyKit

public class MusicFavAPIClient {
    static let baseUrl   = "http://musicfav-cloud.herokuapp.com"
    public static var sharedInstance = MusicFavAPIClient()
    public func playlistify(targetUrl: NSURL, errorOnFailure: Bool) -> SignalProducer<Playlist, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = Alamofire.Manager()
            let url = String(format: "%@/playlistify", MusicFavAPIClient.baseUrl)
            let request = manager.request(.GET, url, parameters: ["url": targetUrl], encoding: ParameterEncoding.URL)
            .responseJSON(options: NSJSONReadingOptions.allZeros) { (req, res, obj, error) -> Void in
                if let e = error {
                    println(error)
                    println(res)
                    if errorOnFailure { sink.put(.Error(Box(e))) }
                    else              { sink.put(.Completed)     }
                } else {
                    sink.put(.Next(Box(Playlist(json: JSON(obj!)))))
                    sink.put(.Completed)
                }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }
}