//
//  PlaylistStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/22.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift

open class PlaylistStreamRepository: EnclosureStreamRepository<ServicePlaylist> {
    open static var sharedPipe: (Signal<ServicePlaylist, NSError>, Signal<ServicePlaylist, NSError>.Observer)! = Signal<ServicePlaylist, NSError>.pipe()
}
