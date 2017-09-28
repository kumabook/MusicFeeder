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
    class fileprivate func getString(_ str: String) -> String? {
        return str == "" ? nil : str
    }
}

open class ProfileStore: RLMObject {
    @objc dynamic var id:         String = ""
    @objc dynamic var email:      String = ""
    @objc dynamic var reader:     String = ""
    @objc dynamic var gender:     String = ""
    @objc dynamic var wave:       String = ""
    @objc dynamic var google:     String = ""
    @objc dynamic var facebook:   String = ""
    @objc dynamic var familyName: String = ""
    @objc dynamic var picture:    String = ""
    @objc dynamic var twitter:    String = ""
    @objc dynamic var givenName:  String = ""
    @objc dynamic var locale:     String = ""
    

    class var realm: RLMRealm {
        return RLMRealm.default()
    }

    open override class func requiredProperties() -> [String] {
        return ["id"]
    }

    override open class func primaryKey() -> String {
        return "id"
    }
}
