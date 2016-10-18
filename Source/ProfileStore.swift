//
//  ProfileStore.swift
//  MusicFeeder
//
//  Created by Hiroki Kumamoto on 10/10/16.
//  Copyright © 2016 kumabook. All rights reserved.
//

import Foundation
import Realm
import FeedlyKit

extension Profile {
    public convenience init(store: ProfileStore) {
        self.init(id: store.id)
        email      = Profile.getString(store.email)
        reader     = Profile.getString(store.reader)
        gender     = Profile.getString(store.gender)
        wave       = Profile.getString(store.wave)
        google     = Profile.getString(store.google)
        facebook   = Profile.getString(store.facebook)
        familyName = Profile.getString(store.familyName)
        picture    = Profile.getString(store.picture)
        twitter    = Profile.getString(store.twitter)
        givenName  = Profile.getString(store.givenName)
        locale     = Profile.getString(store.locale)
    }
    public func toStoreObject() -> ProfileStore {
        let store = ProfileStore()
        store.id         = id
        store.reader     = reader     ?? ""
        store.gender     = gender     ?? ""
        store.wave       = wave       ?? ""
        store.google     = google     ?? ""
        store.facebook   = facebook   ?? ""
        store.familyName = familyName ?? ""
        store.picture    = picture    ?? ""
        store.twitter    = twitter    ?? ""
        store.givenName  = givenName  ?? ""
        store.locale     = locale     ?? ""
        return store
    }
    class private func getString(str: String) -> String? {
        return str == "" ? nil : str
    }
}

public class ProfileStore: RLMObject {
    dynamic var id:         String = ""
    dynamic var email:      String = ""
    dynamic var reader:     String = ""
    dynamic var gender:     String = ""
    dynamic var wave:       String = ""
    dynamic var google:     String = ""
    dynamic var facebook:   String = ""
    dynamic var familyName: String = ""
    dynamic var picture:    String = ""
    dynamic var twitter:    String = ""
    dynamic var givenName:  String = ""
    dynamic var locale:     String = ""
    

    class var realm: RLMRealm {
        return RLMRealm.defaultRealm()
    }

    public override class func requiredProperties() -> [String] {
        return ["id"]
    }

    override public class func primaryKey() -> String {
        return "id"
    }
}
