//
//  CarPlaySceneDelegateTests.swift
//  PlayolaRadio
//

@preconcurrency import CarPlay
import CustomDump
import Dependencies
import IdentifiedCollections
import ObjectiveC
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
    defer { delegate.stationCatalogObservationTask?.cancel() }
    expectNoDifference(connectedRowCount(of: delegate), 2)

    $showSecretStations.withLock { $0 = false }
    await yieldUntil { connectedRowCount(of: delegate) == 1 }

    expectNoDifference(connectedRowCount(of: delegate), 1)
  }

  @Test
  func testCatalogChangeWhileConnectedRebuildsRows() async {
    @Shared(.showSecretStations) var showSecretStations = true
    @Shared(.stationLists) var stationLists = IdentifiedArray(
      uniqueElements: [list(visibilities: [.visible])])
    let delegate = CarPlaySceneDelegate()
    delegate.tabBarTemplate = CPTabBarTemplate(templates: delegate.generateTemplates(stationLists))
    delegate.observeStationCatalog()
    defer { delegate.stationCatalogObservationTask?.cancel() }
    expectNoDifference(connectedRowCount(of: delegate), 1)

    $stationLists.withLock {
      $0 = IdentifiedArray(uniqueElements: [list(visibilities: [.visible, .hidden])])
    }
    await yieldUntil { connectedRowCount(of: delegate) == 2 }

    expectNoDifference(connectedRowCount(of: delegate), 2)
  }

  @Test
  func testPlaybackErrorAfterReconnectShowsAlert() {
    let player = StationPlayerMock()
    let delegate = delegate(using: player)
    let firstController = FakeInterfaceController.make()
    connect(delegate, to: firstController)
    disconnect(delegate, from: firstController)
    let secondController = FakeInterfaceController.make()
    defer { disconnect(delegate, from: secondController) }

    connect(delegate, to: secondController)
    player.state = StationPlayer.State(playbackStatus: .error)

    expectNoDifference(secondController.presentedAlertTitles, [["Unable to Connect"]])
  }

  @Test
  func testReconnectWithoutDisconnectShowsOneAlert() {
    let player = StationPlayerMock()
    let delegate = delegate(using: player)
    let controller = FakeInterfaceController.make()
    defer { disconnect(delegate, from: controller) }
    connect(delegate, to: FakeInterfaceController.make())

    connect(delegate, to: controller)
    player.state = StationPlayer.State(playbackStatus: .error)

    expectNoDifference(controller.presentedAlertTitles.count, 1)
  }

  @Test
  func testMiniPlayerIsTurnedOff() {
    guard #available(iOS 27.0, *) else { return }
    CPNowPlayingTemplate.shared.allowsMiniPlayer = true

    _ = CarPlaySceneDelegate()

    expectNoDifference(CPNowPlayingTemplate.shared.allowsMiniPlayer, false)
  }

  private func delegate(using player: StationPlayerMock) -> CarPlaySceneDelegate {
    withDependencies {
      $0.stationPlayer = player
    } operation: {
      CarPlaySceneDelegate()
    }
  }

  private func connect(_ delegate: CarPlaySceneDelegate, to controller: CPInterfaceController) {
    delegate.templateApplicationScene(FakeInterfaceController.scene(), didConnect: controller)
  }

  private func disconnect(_ delegate: CarPlaySceneDelegate, from controller: CPInterfaceController)
  {
    delegate.templateApplicationScene(
      FakeInterfaceController.scene(), didDisconnectInterfaceController: controller)
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

/// CarPlay's interface controller has no public initializer, so tests allocate the
/// subclass directly and record what the delegate presents. The instance never runs
/// an initializer, so it holds no stored properties; recordings live in an associated object.
private final class FakeInterfaceController: CPInterfaceController {
  private final class Recording {
    var presentedAlerts: [CPAlertTemplate] = []
  }

  private static var recordingKey = 0

  static func make() -> FakeInterfaceController {
    guard
      let controller = class_createInstance(FakeInterfaceController.self, 0)
        as? FakeInterfaceController
    else { preconditionFailure("Could not allocate FakeInterfaceController") }
    objc_setAssociatedObject(controller, &recordingKey, Recording(), .OBJC_ASSOCIATION_RETAIN)
    return controller
  }

  static func scene() -> CPTemplateApplicationScene {
    guard
      let scene = class_createInstance(CPTemplateApplicationScene.self, 0)
        as? CPTemplateApplicationScene
    else { preconditionFailure("Could not allocate CPTemplateApplicationScene") }
    return scene
  }

  private var recording: Recording {
    guard let recording = objc_getAssociatedObject(self, &Self.recordingKey) as? Recording else {
      preconditionFailure("FakeInterfaceController must be created with make()")
    }
    return recording
  }

  var presentedAlertTitles: [[String]] { recording.presentedAlerts.map(\.titleVariants) }

  override var delegate: CPInterfaceControllerDelegate? {
    get { nil }
    set {}
  }

  override var presentedTemplate: CPTemplate? { nil }

  override var topTemplate: CPTemplate? { nil }

  override func setRootTemplate(
    _ rootTemplate: CPTemplate, animated: Bool,
    completion: ((Bool, Error?) -> Void)? = nil
  ) {
    completion?(true, nil)
  }

  override func presentTemplate(
    _ templateToPresent: CPTemplate, animated: Bool,
    completion: ((Bool, Error?) -> Void)? = nil
  ) {
    if let alert = templateToPresent as? CPAlertTemplate {
      recording.presentedAlerts.append(alert)
    }
    completion?(true, nil)
  }
}
