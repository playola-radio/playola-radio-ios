//
//  CarPlaySceneDelegate.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
@preconcurrency import CarPlay
import Combine
import Dependencies
import IdentifiedCollections
import Sharing

@MainActor
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private func tabImage(_ identifier: String) -> UIImage? {
    switch identifier {
    case StationList.KnownIDs.artistList.rawValue:
      return UIImage(systemName: "music.mic.circle")
    case StationList.KnownIDs.fmStationsList.rawValue:
      return UIImage(systemName: "radio")
    default:
      return UIImage(systemName: "music.mic.circle")
    }
  }

  var disposables = Set<AnyCancellable>()

  var interfaceController: CPInterfaceController?

  @Shared(.stationLists) var stationLists
  @Shared(.showSecretStations) var showSecretStations

  var tabBarTemplate: CPTabBarTemplate?

  var observers = Set<AnyCancellable>()

  @Dependency(\.analytics) var analytics
  @Dependency(\.stationPlayer) var stationPlayer

  /// True while a CarPlay push/pop is animating. Every navigation op is async, so
  /// issuing a second one before the first completes can overlap and re-trigger the
  /// "same template instance" rejection. Set before a push/pop, cleared in its
  /// completion (unlike the old synchronous `defer` guard, which cleared before the
  /// op ever finished and therefore serialized nothing).
  private var navigationInFlight = false

  /// The most recent desired Now Playing visibility requested while a navigation
  /// op was in flight. Applied when that op completes (latest wins), so a rapid
  /// stop→play can't strand us in the wrong state.
  private var pendingNowPlayingVisible: Bool?

  /// Incremented for each nav op so the watchdog can tell whether the op it was
  /// scheduled for is still the one in flight (vs. already completed and replaced).
  private var navigationGeneration = 0

  override init() {
    super.init()
    setupNowPlayingTemplate()
    observePlaybackErrors()
  }

  private func playStation(_ station: AnyStation?) {
    guard let station else { return }

    Task { @MainActor in
      await stationPlayer.play(station: station)
    }

    // Show Now Playing immediately on tap, routed through the SAME serialized
    // reconciler as the observer — not a second, racing writer (that was half of
    // the "stuck on the list" bug). Going through `setNowPlaying` also covers
    // re-tapping the already-playing station: `play()` early-returns without a
    // status change, so the observer emits nothing and only this call surfaces
    // Now Playing.
    setNowPlaying(visible: true)
  }

  private func sectionFromStations(_ stations: [AnyStation]) -> CPListSection {
    let listItems: [CPListItem] = stations.map { station in
      let listItem = self.cPListItemFrom(station: station)
      listItem.handler = { _, completion in
        self.playStation(station)
        completion()
      }
      return listItem
    }
    return CPListSection(items: listItems)
  }

  private func templateFromStationList(_ stationList: StationList) -> CPListTemplate {
    let section = sectionFromStations(stationList.stations)
    let template = CPListTemplate(title: stationList.title, sections: [section])
    template.tabTitle = stationList.title
    template.tabImage = tabImage(stationList.id)
    return template
  }

  func generateTemplates(_ stationLists: IdentifiedArrayOf<StationList>) -> [CPListTemplate] {
    stationLists
      .filter { $0.stations.count > 0 }
      .filter { $0.id != StationList.KnownIDs.inDevelopmentList.rawValue || showSecretStations }
      .map { templateFromStationList($0) }
  }

  nonisolated func templateApplicationScene(
    _ scene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    MainActor.assumeIsolated {
      Task {
        await analytics.track(.carPlayInitialized)
      }
      $stationLists.publisher
        .sink { stationLists in
          let newTemplates = self.generateTemplates(stationLists)
          self.tabBarTemplate?.updateTemplates(newTemplates)
        }
        .store(in: &observers)

      self.interfaceController = interfaceController
      self.interfaceController?.delegate = self

      tabBarTemplate = CPTabBarTemplate(templates: generateTemplates(stationLists))
      tabBarTemplate?.delegate = self

      guard let tabBarTemplate = tabBarTemplate else { return }
      self.interfaceController?.setRootTemplate(tabBarTemplate, animated: true) {
        [weak self] _, _ in
        guard let self else { return }
        // Replay the current playback status now that the controller exists. The
        // $state observer's first emission arrives during init (before this
        // controller exists) and is then deduplicated, so without this replay a
        // session already playing/loading/erroring when CarPlay connects would be
        // stuck on the station list until the next real status transition.
        self.apply(CarPlayPlaybackTransition.action(for: self.stationPlayer.state.playbackStatus))
      }
    }
  }

  nonisolated func templateApplicationScene(
    _ scene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    MainActor.assumeIsolated {
      self.interfaceController = nil

      // Reset navigation state: a push/pop that was mid-flight when CarPlay
      // disconnected will never call its completion, so without this
      // `navigationInFlight` would stay true and block every future transition
      // after a reconnect (this delegate instance is reused).
      navigationInFlight = false
      pendingNowPlayingVisible = nil

      for observer in observers {
        observer.cancel()
      }
      observers.removeAll()
      CPListItem.clearImageCache()
    }
  }

  private func setupNowPlayingTemplate() {
    @Dependency(\.nowPlayingUpdater) var nowPlayingUpdater
    _ = nowPlayingUpdater
  }

  private func observePlaybackErrors() {
    // Only react to actual playback-status transitions. `state` republishes on
    // artwork/metadata updates without a status change; without `removeDuplicates`
    // every such update would re-run the template logic and (because `.playing`
    // shows Now Playing) yank the user back to Now Playing while they are browsing
    // the station list mid-playback.
    // Dedupe on the CarPlay *action*, not the raw `playbackStatus`. The Playola
    // SDK streams `.loading(station, progress)` with a changing progress float on
    // every buffering tick, so `removeDuplicates()` on the status never collapses
    // them and `handleStationLoading()` fires hundreds of times — each re-pushing
    // `CPNowPlayingTemplate.shared`, which CarPlay rejects ("Pushing the same
    // template instance more than once"), stranding the user on the station list.
    // `.loading` and `.playing` both map to `.showNowPlaying`, so deduping on the
    // action collapses the whole flood to a single push.
    stationPlayer.$state
      .map { CarPlayPlaybackTransition.action(for: $0.playbackStatus) }
      .removeDuplicates()
      .sink { [weak self] action in
        self?.apply(action)
      }
      .store(in: &observers)
  }

  /// Applies a CarPlay template change for the given transition action. Shared by
  /// the live `$state` observer and the `didConnect` replay so both paths run
  /// through the same (unit-tested) `CarPlayPlaybackTransition` logic.
  ///
  /// `.showNowPlaying` fires for `.playing` too (not just `.loading`): if a stray
  /// `.stopped` ever dismissed Now Playing, the next transition into `.playing`
  /// restores it instead of leaving the user stuck on the station list.
  private func apply(_ action: CarPlayPlaybackTransition.Action) {
    switch action {
    case .showNowPlaying:
      handleStationLoading()
    case .removeNowPlaying:
      handleStationStopped()
    case .showError:
      handlePlaybackError()
    case .none:
      break
    }
  }

  private func handleStationLoading() {
    guard let interfaceController else { return }

    // If an alert (e.g. a prior "Unable to Connect") is up, dismiss it first and
    // show Now Playing from the dismissal completion so the two CarPlay animations
    // don't overlap. No alert: show immediately.
    if interfaceController.presentedTemplate != nil {
      interfaceController.dismissTemplate(animated: true) { [weak self] _, _ in
        self?.setNowPlaying(visible: true)
      }
    } else {
      setNowPlaying(visible: true)
    }
  }

  private func handleStationStopped() {
    // Don't leave Now Playing while we're just seeking to another station.
    if stationPlayer.isSeeking { return }
    setNowPlaying(visible: false)
  }

  /// Serialized reconciler toward "Now Playing visible" or "station list visible".
  ///
  /// All decisions use `topTemplate` (reliable), never `templates.contains(_:)`:
  /// under a `CPTabBarTemplate` root that array does NOT include the shared Now
  /// Playing singleton, so it reports `false` even when CarPlay still holds the
  /// instance — trusting it made the code push a second time, which CarPlay rejects
  /// with "Pushing the same template instance more than once", stranding the user
  /// on the station list.
  ///
  /// Only one push/pop runs at a time (`navigationInFlight`); a request that
  /// arrives mid-animation is coalesced into `pendingNowPlayingVisible` and applied
  /// on completion.
  private func setNowPlaying(visible: Bool) {
    guard let interfaceController else { return }

    guard !navigationInFlight else {
      pendingNowPlayingVisible = visible
      return
    }

    let isShowing = interfaceController.topTemplate == CPNowPlayingTemplate.shared
    guard visible != isShowing else {
      pendingNowPlayingVisible = nil  // desired state reached; drop any stale intent
      return
    }

    navigationInFlight = true
    navigationGeneration += 1
    scheduleNavigationWatchdog(for: navigationGeneration)
    if visible {
      interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) {
        [weak self] _, error in
        guard let self else { return }
        guard error != nil else {
          self.navigationCompleted()
          return
        }
        // Push rejected — the shared singleton is already in the hierarchy. Surface
        // that existing instance instead of failing. One push, one recovery pop;
        // never recurse.
        self.interfaceController?.pop(to: CPNowPlayingTemplate.shared, animated: true) {
          [weak self] _, _ in
          self?.navigationCompleted()
        }
      }
    } else {
      interfaceController.popToRootTemplate(animated: true) { [weak self] _, _ in
        self?.navigationCompleted()
      }
    }
  }

  private func navigationCompleted() {
    navigationInFlight = false
    guard let pending = pendingNowPlayingVisible else { return }
    pendingNowPlayingVisible = nil
    setNowPlaying(visible: pending)
  }

  /// Failsafe for a dropped CarPlay completion. Push/pop completions are normally
  /// always delivered, but if one is ever lost during transient controller
  /// disruption (without a full disconnect, which already resets state),
  /// `navigationInFlight` would stay true and silently block every future
  /// transition. If the op that bumped `generation` is still in flight after a
  /// grace period, clear the gate and re-reconcile from the current player state.
  private func scheduleNavigationWatchdog(for generation: Int) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard let self,
        self.navigationInFlight,
        self.navigationGeneration == generation
      else { return }  // completed normally, or superseded by a newer op

      self.navigationInFlight = false
      if let pending = self.pendingNowPlayingVisible {
        self.pendingNowPlayingVisible = nil
        self.setNowPlaying(visible: pending)
      } else {
        self.apply(CarPlayPlaybackTransition.action(for: self.stationPlayer.state.playbackStatus))
      }
    }
  }

  private func handlePlaybackError() {
    guard let interfaceController = interfaceController else { return }

    // Don't show multiple error alerts
    if interfaceController.presentedTemplate is CPAlertTemplate {
      return
    }

    // Create title with station name for context
    let titleVariants: [String]
    if let station = stationPlayer.currentStation {
      titleVariants = ["Unable to Connect to \(station.name)"]
    } else {
      titleVariants = ["Unable to Connect"]
    }

    // Create alert with single action
    let alert = CPAlertTemplate(
      titleVariants: titleVariants,
      actions: [
        CPAlertAction(title: "Choose Another Station", style: .default) { [weak self] _ in
          self?.popToStationList()
        }
      ]
    )

    // Present alert
    interfaceController.presentTemplate(alert, animated: true) { success, error in
      if !success {
        print("Failed to present error alert: \(error?.localizedDescription ?? "Unknown error")")
      }
    }
  }

  private func popToStationList() {
    guard let interfaceController else { return }

    // Dismiss the alert, then return to the list via the shared reconciler.
    // Routing through `setNowPlaying(visible:)` keeps a single navigation writer
    // and avoids `templates.count`, which is unreliable under a tab-bar root.
    if interfaceController.presentedTemplate != nil {
      interfaceController.dismissTemplate(animated: true) { [weak self] _, _ in
        self?.setNowPlaying(visible: false)
      }
    } else {
      setNowPlaying(visible: false)
    }
  }

  /// Creates a CPListItem from a RadioStation
  /// - Parameter station: The radio station to convert
  /// - Returns: A configured CPListItem
  public func cPListItemFrom(station: AnyStation) -> CPListItem {
    // Use a default placeholder image for better UX
    let placeholder = UIImage(systemName: "radio") ?? UIImage()

    let listItem = CPListItem(
      text: station.stationName,
      detailText: station.name,
      remoteImageUrl: station.imageUrl,
      placeholder: placeholder
    )
    listItem.handler = { _, completion in
      if station.active {
        Task { @MainActor in
          await self.stationPlayer.play(station: station)
        }
      }
      completion()
    }
    return listItem
  }
}

extension CarPlaySceneDelegate: CPTabBarTemplateDelegate {
  nonisolated func tabBarTemplate(
    _ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate
  ) {
    // Handle tab selection
  }
}

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
  nonisolated func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template will appear
  }

  nonisolated func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template did appear
  }

  nonisolated func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template will disappear
  }

  nonisolated func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template did disappear
  }
}
