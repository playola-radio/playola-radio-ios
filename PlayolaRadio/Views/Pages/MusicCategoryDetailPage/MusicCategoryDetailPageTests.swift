//
//  MusicCategoryDetailPageTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct MusicCategoryDetailPageTests {

  @Test func navigationTitleIsTheProvidedTitle() {
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [])

    expectNoDifference(model.navigationTitle, "Texas Country")
  }

  @Test func showsEmptyStateWhenNoSongs() {
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [])

    #expect(model.showsEmptyState)
  }

  @Test func hidesEmptyStateWhenSongsPresent() {
    let model = MusicCategoryDetailPageModel(
      title: "Texas Country", songs: [.mockWith(id: "a")])

    #expect(!model.showsEmptyState)
  }

  @Test func exposesSongTitleAndSubtitle() {
    let block = AudioBlock.mockWith(id: "a", title: "Whiskey Sunset", artist: "Bri Bagwell")
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [block])

    expectNoDifference(model.songTitle(for: block), "Whiskey Sunset")
    expectNoDifference(model.songSubtitle(for: block), "Bri Bagwell")
  }
}
