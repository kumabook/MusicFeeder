//
//  PlaylistQueue.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 6/26/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import PlayerKit

public class PlaylistQueue: PlayerKit.PlaylistQueue {
    public init(playlists: [Playlist]) {
        super.init(playlists: playlists)
    }
}