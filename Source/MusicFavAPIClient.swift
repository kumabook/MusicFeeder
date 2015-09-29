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
import Alamofire
import FeedlyKit

public class MusicFavAPIClient {
    static let baseUrl   = "http://musicfav-cloud.herokuapp.com"
    public static var sharedInstance = MusicFavAPIClient()
    static var sharedManager: Alamofire.Manager! = Alamofire.Manager()

    public func playlistify(targetUrl: NSURL, errorOnFailure: Bool) -> SignalProducer<Playlist, NSError> {
        return SignalProducer { (sink, disposable) in
            let url = String(format: "%@/playlistify", MusicFavAPIClient.baseUrl)
            let request = MusicFavAPIClient.sharedManager.request(.GET, url, parameters: ["url": targetUrl], encoding: ParameterEncoding.URL)
            .responseJSON(options: NSJSONReadingOptions()) { (req, res, result) -> Void in
                if let e = result.error {
                    if errorOnFailure { sink(.Error(e as NSError)) }
                    else              { sink(.Completed) }
                } else {
                    sink(.Next(Playlist(json: JSON(result.value!))))
                    sink(.Completed)
                }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }
}