//
//  CarPlaySceneDelegateTests.swift
//  PlayolaRadio
//

@preconcurrency import CarPlay
import CustomDump
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
    hidden: Bool = false, visibilities: [StationListItemVisibility]
  ) -> StationList {
    let id = "list"
    return StationList(
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

    expectNoDifference(rows(of: templates[0]).count, 2)
  }

  @Test
  func testUnlockedDeviceGetsSecretRow() {
    @Shared(.showSecretStations) var showSecretStations = true
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates(
      [list(visibilities: [.visible, .hidden, .comingSoon])])

    expectNoDifference(rows(of: templates[0]).count, 3)
  }

  @Test
  func testTemplateIsBuiltForListFlaggedHidden() {
    @Shared(.showSecretStations) var showSecretStations = false
    let delegate = CarPlaySceneDelegate()

    let templates = delegate.generateTemplates([list(hidden: true, visibilities: [.visible])])

    expectNoDifference(templates.count, 1)
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
    await waitForFirstPlay(on: player)

    expectNoDifference(player.callsToPlay.map(\.id), ["list-1"])
  }

  @Test
  func testTappingSecretRowAfterDeviceIsLockedDoesNotPlay() async {
    @Shared(.showSecretStations) var showSecretStations = true
    let player = StationPlayerMock()
    let delegate = withDependencies {
      $0.stationPlayer = player
    } operation: {
      CarPlaySceneDelegate()
    }
    let templates = delegate.generateTemplates([list(visibilities: [.hidden, .visible])])
    let tappedRows = rows(of: templates[0])

    $showSecretStations.withLock { $0 = false }
    tap(tappedRows[0])
    tap(tappedRows[1])
    await waitForFirstPlay(on: player)

    expectNoDifference(player.callsToPlay.map(\.id), ["list-1"])
  }

  @Test
  func testRelockingWhileConnectedRemovesHiddenRow() async {
    @Shared(.showSecretStations) var showSecretStations = true
    @Shared(.stationLists) var stationLists = IdentifiedArray(
      uniqueElements: [list(visibilities: [.visible, .hidden])])
    let delegate = CarPlaySceneDelegate()
    delegate.tabBarTemplate = CPTabBarTemplate(templates: delegate.generateTemplates(stationLists))
    delegate.observeStationCatalog()
    expectNoDifference(connectedRowCount(of: delegate), 2)

    $showSecretStations.withLock { $0 = false }
    await yieldUntil { connectedRowCount(of: delegate) == 1 }

    expectNoDifference(connectedRowCount(of: delegate), 1)
  }

  private func connectedRowCount(of delegate: CarPlaySceneDelegate) -> Int {
    guard let template = delegate.tabBarTemplate?.templates.first as? CPListTemplate else {
      return 0
    }
    return rows(of: template).count
  }

  private func yieldUntil(_ condition: () -> Bool) async {
    var yields = 0
    while !condition() && yields < 1000 {
      await Task.yield()
      yields += 1
    }
  }

  private func waitForFirstPlay(on player: StationPlayerMock) async {
    var yields = 0
    while player.callsToPlay.isEmpty && yields < 1000 {
      await Task.yield()
      yields += 1
    }
    #expect(!player.callsToPlay.isEmpty, "Expected a tapped CarPlay row to start playback")
  }
}
