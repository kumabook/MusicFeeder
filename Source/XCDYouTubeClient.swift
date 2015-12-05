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
        return SignalProducer { (observer, disposable) in
            let operation = self.getVideoWithIdentifier(identifier, completionHandler: { (video, error) -> Void in
                if let e = error {
                    observer.sendFailed(e)
                } else if let v = video {
                    observer.sendNext(v)
                    observer.sendCompleted()
                }
            })
            disposable.addDisposable {
                operation.cancel()
            }
            return
        }
    }
}
