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
    public override func observe() {
        PlaylistStreamRepository.sharedPipe.0.observe {
            guard let item = $0.value else { return }
            guard let index = self.items.index(of: item) else { return }
            self.items[index] = item
        }
    }
}
