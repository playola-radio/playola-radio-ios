//
//  StationListPresetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListPresetTests {

  // MARK: - Preset Loading Tests

  @Test
  func testViewAppearedLoadsPresets() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Bri", lastName: nil, email: "b@example.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "fake-token"
    )
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.stationLists) var stationLists = StationList.mocks

    let returnedPresets = [Preset.mockPlayola(id: "p1"), Preset.mockUrl(id: "p2")]
    let capturedToken = LockIsolated<String?>(nil)

    let model = withDependencies {
      $0.api.getPresets = { token in
        capturedToken.setValue(token)
        return returnedPresets
      }
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    #expect(capturedToken.value == "fake-token")
    expectNoDifference(Array(presets), returnedPresets)
  }

  // MARK: - isPreset

  @Test
  func testIsPresetReturnsTrueForExistingPreset() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(stationId: "playola-1")
    ]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "playola-1"))
  }

  @Test
  func testIsPresetReturnsTrueForUrlStationPreset() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockUrl(urlStationId: "url-1")
    ]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "url-1"))
  }

  @Test
  func testIsPresetReturnsFalseForUnknownStation() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    let model = StationListModel()
    #expect(!model.isPreset(stationId: "nope"))
  }

  @Test
  func testIsPresetReturnsTrueWhilePendingAdd() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = ["playola-2"]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "playola-2"))
  }

  // MARK: - displayPresets

  @Test
  func testDisplayPresetsOrdersByPosition() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    let station2 = Station.mockWith(id: "s2", name: "S2")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p2", stationId: "s2", position: 1),
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0),
    ]

    let model = StationListModel()
    let items = model.displayPresets

    expectNoDifference(items.map(\.id), ["p1", "p2"])
    #expect(items.allSatisfy { !$0.isPending })
  }

  @Test
  func testDisplayPresetsFiltersOrphans() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0),
      Preset.mockPlayola(id: "p-orphan", stationId: "gone", position: 1),
    ]

    let model = StationListModel()
    expectNoDifference(model.displayPresets.map(\.id), ["p1"])
  }

  @Test
  func testDisplayPresetsAppendsPendingAddAsGhostTile() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    let station2 = Station.mockWith(id: "s2", name: "S2")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    ]
    @Shared(.pendingPresetStationIds) var pending: Set<String> = ["s2"]

    let model = StationListModel()
    let items = model.displayPresets

    expectNoDifference(items.map(\.id), ["p1", "pending-s2"])
    expectNoDifference(items.map(\.isPending), [false, true])
    #expect(items[1].stationItem.anyStation.id == "s2")
  }
}

private func makePresetTestList(with items: [APIStationItem], date: Date = Date()) -> StationList {
  StationList(
    id: "preset-test-list",
    name: "Test List",
    slug: "preset-test-list",
    hidden: false,
    sortOrder: 0,
    createdAt: date,
    updatedAt: date,
    items: items
  )
}
