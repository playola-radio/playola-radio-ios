//
//  ArtistStationPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistStationPageTests {
  @Test func displaysPlaceholderHeader() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.navigationTitle, "Station")
    expectNoDifference(model.stationName, "Reckless Radio")
  }

  @Test func displaysPlaceholderBroadcastCard() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.onAirLabel, "ON AIR NOW")
    expectNoDifference(model.broadcastStatusLabel, "Auto DJ")
    expectNoDifference(model.nowPlayingTitle, "Cheat On Your Man")
    expectNoDifference(model.nowPlayingSubtitle, "Bri Bagwell · up next: My Boots")
    expectNoDifference(model.lastWentLiveLabel, "Last went live 4 days ago")
    expectNoDifference(model.broadcastSettingsLabel, "Broadcast settings")
    #expect(model.nowPlayingProgress > 0 && model.nowPlayingProgress <= 1)
  }

  @Test func displaysPlaceholderLinks() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.showsLinkTitle, "Shows")
    expectNoDifference(model.musicLibraryLinkTitle, "Music Library")
    expectNoDifference(model.scheduleLinkTitle, "Schedule")
  }
}
