//
//  XCDYouTubeClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import XCDYouTubeKit
import ReactiveCocoa
import Result

extension XCDYouTubeClient {
    public func fetchVideo(identifier: String) -> SignalProducer<XCDYouTubeVideo, NSError> {
        return SignalProducer { (sink, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    sink(.Error(e))
                } else if let v = video {
                    sink(.Next(v))
                    sink(.Completed)
                }
            })
            disposable.addDisposable {
                operation.cancel()
            }
            return
        }
    }
}
