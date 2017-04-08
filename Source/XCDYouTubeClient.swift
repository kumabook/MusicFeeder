//
//  XCDYouTubeClient.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/7/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import XCDYouTubeKit
import ReactiveSwift
import Result

extension XCDYouTubeClient {
    public func fetchVideo(_ identifier: String) -> SignalProducer<XCDYouTubeVideo, NSError> {
        return SignalProducer { (observer, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    observer.send(error: e as NSError)
                } else if let v = video {
                    observer.send(value: v)
                    observer.sendCompleted()
                }
            })
            disposable.add {
                operation.cancel()
            }
            return
        }
    }
}

extension XCDYouTubeVideo: YouTubeVideo {}
