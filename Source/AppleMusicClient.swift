//
//  AppleMusicClient.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/12.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import StoreKit
import MediaPlayer
import ReactiveSwift

@available(iOS 9.3, *)
public class AppleMusicClient {
    open private(set) var countryCode: String = ""
    open static var shared: AppleMusicClient = AppleMusicClient()
    open var cloudServiceController: SKCloudServiceController
    init() {
        cloudServiceController = SKCloudServiceController()
    }
    public var authroizationStatus: SKCloudServiceAuthorizationStatus {
        return SKCloudServiceController.authorizationStatus()
    }

    public func fetchCountryCode() -> SignalProducer<String?, NSError> {
        return SignalProducer { (observer, disposable) in
            self.cloudServiceController.requestStorefrontIdentifier { (identifier, error) in
                if let error = error as? NSError {
                    observer.send(error: error)
                } else {
                    observer.send(value: identifier.flatMap {
                        $0.characters.split(separator: "-").first
                    }.flatMap {
                        StoreFrontIDs[String($0)]
                    })
                    observer.sendCompleted()
                }
            }
        }
    }

    public func requestAuthorization() -> SignalProducer<SKCloudServiceAuthorizationStatus, NSError> {
        return SignalProducer { (observer, disposable) in
            SKCloudServiceController.requestAuthorization { (status: SKCloudServiceAuthorizationStatus) in
                observer.send(value: status)
                observer.sendCompleted()
            }
        }
    }
    public func requestCapabilities() -> SignalProducer<SKCloudServiceCapability, NSError> {
        return SignalProducer { (observer, disposable) in
            self.cloudServiceController.requestCapabilities { (capability: SKCloudServiceCapability, error: Error?) in
                if let error = error {
                    observer.send(error: error as NSError)
                    return
                }
                observer.send(value: capability)
                observer.sendCompleted()
            }
        }
    }

    #if os(iOS)
    open func addToLibrary(track: Track) -> SignalProducer<[MPMediaEntity], NSError> {
        return SignalProducer { (observer, disposable) in
            MPMediaLibrary.default().addItem(withProductID: track.identifier) { (entities, error) in
                UIScheduler().schedule {
                    if let e = error as? NSError {
                        observer.send(error: e as NSError)
                        return
                    }
                    observer.send(value: entities)
                    observer.sendCompleted()
                }
            }
        }
    }
    open func addToLibrary(album: Album) -> SignalProducer<[MPMediaEntity], NSError> {
        return SignalProducer { (observer, disposable) in
            MPMediaLibrary.default().addItem(withProductID: album.identifier) { (entities, error) in
                UIScheduler().schedule {
                    if let e = error as? NSError {
                        observer.send(error: e as NSError)
                        return
                    }
                    observer.send(value: entities)
                    observer.sendCompleted()
                }
            }
        }
    }
    open func getPlaylists() -> [MPMediaPlaylist]? {
        return MPMediaQuery.playlists().collections?
                .filter { $0 is MPMediaPlaylist }
                .map { $0 as! MPMediaPlaylist }
    }

    open func addToLibrary(playlist: ServicePlaylist) -> SignalProducer<[MPMediaEntity], NSError> {
        return SignalProducer { (observer, disposable) in
            MPMediaLibrary.default().addItem(withProductID: playlist.identifier) { (entities, error) in
                UIScheduler().schedule {
                    if let e = error as? NSError {
                        observer.send(error: e as NSError)
                        return
                    }
                    observer.send(value: entities)
                    observer.sendCompleted()
                }
            }
        }
    }

    open func add(track: Track, to playlist: MPMediaPlaylist) -> SignalProducer<Void, NSError> {
        return SignalProducer { (observer, disposable) in
            playlist.addItem(withProductID: track.identifier) { error in
                if let e = error as? NSError {
                    observer.send(error: e as NSError)
                    return
                }
                observer.send(value: ())
                observer.sendCompleted()
            }
        }
    }
    #endif
}
