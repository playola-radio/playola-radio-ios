//
//  YourLibraryPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct YourLibraryPageTests {
  @Test
  func testNavigationTitleIsYourLibrary() {
    let model = YourLibraryPageModel()
    #expect(model.navigationTitle == "Your Library")
  }

  @Test
  func testPresetTileTappedPlaysStation() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let item = presetItem("s1")
    @Shared(.stationLists) var sharedLists = presetStationLists("s1")

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let captured = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      YourLibraryPageModel()
    }

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.first?.id == "s1")
    let tracked = captured.value.contains {
      if case .presetTileTapped = $0 { return true }
      return false
    }
    #expect(tracked)
  }

  @Test
  func testPresetTileTappedNoOpInEditMode() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let item = presetItem("s1")
    @Shared(.stationLists) var sharedLists = presetStationLists("s1")

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { _ in }
    } operation: {
      YourLibraryPageModel()
    }
    model.presetsModel.presetListState = .editing

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.isEmpty)
  }

  // MARK: - Liked Songs

  @Test
  func testLikedSongsReflectsLikedTracks() {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")

    withDependencies {
      $0.date.now = Date()
      let likesManager = LikesManager()
      likesManager.like(audioBlock1)
      likesManager.like(audioBlock2)
      $0.likesManager = likesManager
    } operation: {
      let model = YourLibraryPageModel()

      #expect(model.likedSongs.count == 2)
    }
  }

  @Test
  func testSongMenuTappedPresentsActionSheet() {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = YourLibraryPageModel()

      #expect(model.presentedSongActionSheet == nil)

      model.songMenuTapped(for: audioBlock, likedDate: Date())

      #expect(model.presentedSongActionSheet?.audioBlock.id == audioBlock.id)
    }
  }

  @Test
  func testRemoveSongUnlikesTrack() {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    withDependencies {
      $0.date.now = Date()
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = YourLibraryPageModel()

      #expect(model.likedSongs.count == 1)

      model.removeSong(audioBlock)

      #expect(model.likedSongs.isEmpty)
    }
  }
}

private func presetItem(_ stationId: String, sortOrder: Int = 0) -> APIStationItem {
  APIStationItem(
    sortOrder: sortOrder, visibility: .visible,
    station: Station.mockWith(id: stationId), urlStation: nil)
}

private func presetStationLists(_ stationIds: String...) -> IdentifiedArrayOf<StationList> {
  IdentifiedArrayOf(uniqueElements: [
    makePresetTestList(with: stationIds.enumerated().map { presetItem($1, sortOrder: $0) })
  ])
}

private func makePresetTestList(with items: [APIStationItem], date: Date = Date()) -> StationList {
  StationList(
    id: "preset-test-list", name: "Test List", slug: "preset-test-list",
    hidden: false, sortOrder: 0, createdAt: date, updatedAt: date, items: items)
}
