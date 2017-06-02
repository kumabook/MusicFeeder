//
//  AlbumStreamRepository.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/03/22.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import ReactiveSwift

open class AlbumStreamRepository: EnclosureStreamRepository<Album> {
    open static var sharedPipe: (Signal<Album, NSError>, Signal<Album, NSError>.Observer)! = Signal<Album, NSError>.pipe()
    public override func observe() {
        AlbumStreamRepository.sharedPipe.0.observe {
            guard let item = $0.value else { return }
            guard let index = self.items.index(of: item) else { return }
            self.items[index] = item
        }
    }
    open func renew() -> AlbumStreamRepository {
        return AlbumStreamRepository(stream: stream, unreadOnly: unreadOnly, perPage: perPage)
    }
}
