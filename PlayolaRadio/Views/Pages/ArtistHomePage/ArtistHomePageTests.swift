//
//  ArtistHomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistHomePageTests {
  @Test func displaysPlaceholderStationName() {
    let model = ArtistHomePageModel()

    expectNoDifference(model.stationName, "Reckless Radio")
  }

  @Test func displaysPlaceholderNowPlaying() {
    let model = ArtistHomePageModel()

    expectNoDifference(model.onAirLabel, "ON AIR NOW")
    expectNoDifference(model.broadcastStatusLabel, "Auto DJ")
    expectNoDifference(model.nowPlayingTitle, "Cheat On Your Man")
    expectNoDifference(model.nowPlayingSubtitle, "Bri Bagwell · up next: My Boots")
    expectNoDifference(model.lastWentLiveLabel, "Last went live 4 days ago")
    expectNoDifference(model.manageBroadcastLabel, "Manage broadcast")
    #expect(model.nowPlayingProgress > 0 && model.nowPlayingProgress < 1)
  }

  @Test func displaysPlaceholderImprovementItems() {
    let model = ArtistHomePageModel()

    expectNoDifference(model.improveSectionTitle, "IMPROVE YOUR STATION")
    expectNoDifference(model.improvementCountLabel, "5")
    expectNoDifference(
      model.improvementItems.map(\.title),
      [
        "Answer Sarah's question",
        "Approve a song request",
        "AMA show Saturday",
        "Record 12 missing intros",
        "Add 8 songs to your library",
      ]
    )
  }

  @Test func displaysLinkTitles() {
    let model = ArtistHomePageModel()

    expectNoDifference(model.showsLinkTitle, "Shows")
    expectNoDifference(model.musicLibraryLinkTitle, "Music Library")
  }
}
