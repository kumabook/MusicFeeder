//
//  PlaylistSpec.swift
//  MusicFav
//
//  Created by Hiroki Kumamoto on 4/25/15.
//  Copyright (c) 2015 Hiroki Kumamoto. All rights reserved.
//

import MusicFeeder
import Quick
import Nimble
import SwiftyJSON

class PlaylistSpec: QuickSpec {
    override func spec() {
        var playlist: Playlist!
        beforeSuite {
            JSONCache.shared.clear()
        }
        beforeEach {
            let json = JSON(SpecHelper.fixtureJSONObject(fixtureNamed: "playlist")!)
            playlist = Playlist(json: json)
        }
        afterEach {
            Playlist.removeAll()
            Track.removeAll()
        }

        describe("A Playlist") {
            it("should be constructed with json") {
                expect(playlist).notTo(beNil())
                expect(playlist.id).to(equal("http://dummy.com/playlist.html"))
                expect(playlist.title).to(equal("playlist_title"))
                expect(playlist.tracks.count).to(equal(2))
            }
            it("should create if not exist") {
                var playlists = Playlist.findAll()
                expect(playlists.count).to(equal(0))
                expect(playlist.create()).to(equal(PersistentResult.success))
                expect(playlist.create()).to(equal(PersistentResult.failure))
                playlists = Playlist.findAll()
                expect(playlists.count).to(equal(1))
                expect(Track.findAll().count).to(equal(2))
            }
            it("should save if exist") {
                var playlists = Playlist.findAll()
                expect(playlists.count).to(equal(0))
                expect(playlist.save()).to(equal(false))
                expect(playlist.create()).to(equal(PersistentResult.success))
                expect(playlist.save()).to(equal(true))
                playlists = Playlist.findAll()
                expect(playlists.count).to(equal(1))
            }
            it("should append and remove track") {
                expect(playlist.create()).to(equal(PersistentResult.success))
                expect(playlist.tracks.count).to(equal(2))
                let track = Track(id: "", provider: Provider.youTube, url: "http://dummy.com", identifier: "12345", title: nil)
                let _ = playlist.appendTracks([track])
                expect(playlist.tracks.count).to(equal(3))
                expect(Track.findAll().count).to(equal(3))
                playlist.removeTrackAtIndex(0)
                expect(playlist.tracks.count).to(equal(2))
                expect(Track.findAll().count).to(equal(3)) // because track also can be in another playlist
            }
        }
    }
}
