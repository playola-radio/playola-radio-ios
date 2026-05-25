//
//  StationListPresetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import IdentifiedCollections
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
}
