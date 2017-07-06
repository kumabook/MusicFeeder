//
//  Profile.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 2017/07/06.
//  Copyright © 2017 kumabook. All rights reserved.
//

import Foundation
import FeedlyKit

extension Profile {
    public var name: String? {
        get {
            return fullName
        }
        set {
            fullName = newValue
        }
    }
    public func toParams() -> [String: Any] {
        return [
            "id":             id,
            "email":          email ?? "",
            "givenName":      givenName ?? "",
            "familyName":     familyName ?? "",
            "fullName":       fullName ?? "",
            "picture":        picture ?? "",
            "gender":         gender ?? "",
            "locale":         locale ?? "",
            "reader":         reader ?? "",
            "wave":           wave ?? "",
            "google":         google ?? "",
            "facebook":       facebook ?? "",
            "facebookUserId": facebookUserId ?? "",
            "twitter":        twitter ?? "",
            "twitterUserId":  twitterUserId ?? "",
            "wordPressId":    wordPressId ?? "",
            "windowsLiveId":  windowsLiveId ?? "",
            "client":         client,
            "source":         source,
            "created":        created ?? 0,
        ]
    }
}
