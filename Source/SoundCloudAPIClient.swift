//
//  SoundCloudAPIClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 12/30/14.
//  Copyright (c) 2014 Hiroki Kumamoto. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa
import Result
import Box
import Alamofire


public class SoundCloudAPIClient {

    static var clientId = "Put_your_SoundCloud_app_client_id"
    static var baseUrl  = "http://api.soundcloud.com"
    static var sharedInstance = SoundCloudAPIClient(clientId: clientId)

    public class func loadConfig() {
        let bundle = NSBundle.mainBundle()
        if let path = bundle.pathForResource("soundcloud", ofType: "json") {
            let data     = NSData(contentsOfFile: path)
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil)
            if let obj: AnyObject = jsonObject {
                let json = JSON(obj)
                if let clientId = json["client_id"].string {
                    SoundCloudAPIClient.clientId = clientId
                }
            }
        }
    }

    public let clientId: String

    public init(clientId: String) {
        self.clientId = clientId
    }

    public func fetchTrack(track_id: String) -> SignalProducer<SoundCloudAudio, NSError> {
        return SignalProducer { (sink, disposable) in
            let manager = Alamofire.Manager()
            let url = String(format: "%@/tracks/%@.json", SoundCloudAPIClient.baseUrl, track_id)
            let request = manager.request(.GET, url,parameters: ["client_id": self.clientId], encoding: ParameterEncoding.URL)
                .responseJSON(options: NSJSONReadingOptions.allZeros) { (req, res, obj, error) -> Void in
                    if let e = error {
                        sink.put(.Error(Box(e)))
                    } else {
                        sink.put(.Next(Box(SoundCloudAudio(json: JSON(obj!)))))
                        sink.put(.Completed)
                    }
            }
            disposable.addDisposable {
                request.cancel()
            }
        }
    }
    public func streamUrl(track_id: Int) -> NSURL {
        return NSURL(string:String(format:"%@/tracks/%@/stream?client_id=%@",
                                SoundCloudAPIClient.baseUrl,
                                track_id,
                                clientId))!
    }
}
