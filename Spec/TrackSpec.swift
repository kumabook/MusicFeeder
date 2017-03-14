//
//  TrackSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/25/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import MusicFeeder
import SwiftyJSON
import Quick
import Nimble

class TrackSpec: QuickSpec {
    override func spec() {
        var track: Track!
        beforeEach {
            let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "track")!)
            track = Track(json: json)
        }

        afterEach { Track.removeAll() }

        describe("A Track") {
            it("should be constructed with json") {
                expect(track).notTo(beNil())
                expect(track.provider).to(equal(Provider.youTube))
                expect(track.identifier).to(equal("abcdefg"))
            }

            it("should create if not exist") {
                var tracks = Track.findAll()
                expect(tracks.count).to(equal(0))
                expect(track.create()).to(equal(true))
                expect(track.create()).to(equal(false))
                tracks = Track.findAll()
                expect(tracks.count).to(equal(1))
            }

            it("should save if exist") {
                let tracks = Track.findAll()
                expect(tracks.count).to(equal(0))
                expect(track.save()).to(equal(false))
                expect(track.create()).to(equal(true))
                expect(track.save()).to(equal(true))
            }
            
            it("should be constructed with a url string that has query") {
                let url = "typica://v3/tracks/aaaa?id=aaaa&identifier=I6l151j_NHQ&likesCount=10&provider=YouTube&title=title"
                let t = Track(urlString: url)!
                expect(t.id).to(equal("aaaa"))
                expect(t.identifier).to(equal("I6l151j_NHQ"))
                expect(t.provider).to(equal(Provider.youTube))
                expect(t.title).to(equal(""))
                expect(t.likesCount!).to(equal(10))
                
                let url2 = "typica://v3/tracks/bbbb?id=bbbb&identifier=I6l151j_NHQ&likesCount=10&provider=YouTube&title=title"
                let t2 = Track(urlString: url2)!
                expect(t2.title).to(equal("title"))
            }
        }
    }
}
