//
//  Entry.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/1/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import Foundation
import FeedlyKit

extension Entry {
    public var url: NSURL? {
        if let alternate = self.alternate {
            if alternate.count > 0 {
                return NSURL(string: alternate[0].href)!
            }
        }
        return nil
    }
    public var enclosureTracks: [Track] {
        return enclosure.map {
            $0.filter { $0.type.contains("audio") }.map {
                Track(provider: .Raw, url: $0.href, identifier: $0.href, title: self.title)
            }
        } ?? []
    }
    public var passedTime: String {
        return published.date.passedTime
    }
}
