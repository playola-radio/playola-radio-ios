//
//  StationListPresetComingSoonTests.swift
//  PlayolaRadio
//

import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListPresetComingSoonTests {

  @Test
  func testDisplayPresetsHidesComingSoonWhenSecretStationsUnlocked() async {
    @Shared(.showSecretStations) var showSecretStations = true
    let item = APIStationItem(
      sortOrder: 0, visibility: .comingSoon,
      station: Station.mockWith(id: "s1"), urlStation: nil)
    #expect(presetSubtitle(for: item) == nil)
  }

  @Test
  func testDisplayPresetsShowsComingSoonWhenSecretStationsHidden() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let item = APIStationItem(
      sortOrder: 0, visibility: .comingSoon,
      station: Station.mockWith(id: "s1"), urlStation: nil)
    #expect(presetSubtitle(for: item) == "Coming Soon")
  }

  @Test
  func testDisplayPresetsShowsComingSoonForInactiveStationEvenWhenSecretStationsUnlocked() async {
    @Shared(.showSecretStations) var showSecretStations = true
    let item = APIStationItem(
      sortOrder: 0, visibility: .visible,
      station: Station.mockWith(id: "s1", active: false), urlStation: nil)
    #expect(presetSubtitle(for: item) == "Coming Soon")
  }

  private func presetSubtitle(for item: APIStationItem) -> String? {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      StationList(
        id: "preset-test-list", name: "Test List", slug: "preset-test-list",
        hidden: false, sortOrder: 0, createdAt: Date(), updatedAt: Date(), items: [item])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: item.anyStation.id, position: 0)
    ]
    return StationListModel().displayPresets.first?.subtitleText
  }
}
