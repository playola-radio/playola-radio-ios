//
//  CarPlaySceneDelegateTests.swift
//  PlayolaRadio
//

@preconcurrency import CarPlay
import Dependencies
import IdentifiedCollections
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct CarPlaySceneDelegateTests {
  private func urlStation(id: String) -> UrlStation {
    UrlStation(
      id: id, name: "Station \(id)", streamUrl: "https://example.com/\(id)",
      imageUrl: "https://example.com/\(id).png", description: "d", website: nil,
      location: "Austin, TX", active: true, createdAt: Date(), updatedAt: Date())
  }

  private func list(
    id: String = "list", hidden: Bool = false, visibilities: [StationListItemVisibility]
  ) -> StationList {
    StationList(
      id: id, name: "List \(id)", slug: id, hidden: hidden, createdAt: Date(), updatedAt: Date(),
      items: visibilities.enumerated().map { index, visibility in
        APIStationItem(
          sortOrder: index, visibility: visibility, station: nil,
          urlStation: urlStation(id: "\(id)-\(index)"))
      })
  }

  private func rows(of template: CPListTemplate) -> [CPListItem] {
    template.sections.flatMap(\.items).compactMap { $0 as? CPListItem }
  }

  private func tap(_ row: CPListItem) {
    row.handler?(row) {}
  }

  @Test
  func testLockedDeviceGetsNoSecretRow() {
    @Shared(.showSecretStations) var showSecretStations = false
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates(
      [list(visibilities: [.visible, .hidden, .comingSoon])])

    #expect(rows(of: templates[0]).count == 2)
  }

  @Test
  func testUnlockedDeviceGetsSecretRow() {
    @Shared(.showSecretStations) var showSecretStations = true
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates(
      [list(visibilities: [.visible, .hidden, .comingSoon])])

    #expect(rows(of: templates[0]).count == 3)
  }

  @Test
  func testTemplateIsBuiltForListFlaggedHidden() {
    @Shared(.showSecretStations) var showSecretStations = false
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates([list(hidden: true, visibilities: [.visible])])

    #expect(templates.count == 1)
  }

  @Test
  func testNoTemplateWhenLockedAndEveryItemIsSecret() {
    @Shared(.showSecretStations) var showSecretStations = false
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates([list(visibilities: [.hidden])])

    #expect(templates.isEmpty)
  }

  @Test
  func testTappingComingSoonRowWhenLockedDoesNotPlay() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let player = StationPlayerMock()
    let delegate = withDependencies {
      $0.stationPlayer = player
    } operation: {
      CarPlaySceneDelegate()
    }
    let templates = delegate.generateTemplates([list(visibilities: [.comingSoon, .visible])])
    let tappedRows = rows(of: templates[0])

    tap(tappedRows[0])
    tap(tappedRows[1])
    while player.callsToPlay.isEmpty { await Task.yield() }

    #expect(player.callsToPlay.map(\.id) == ["list-1"])
  }
}
