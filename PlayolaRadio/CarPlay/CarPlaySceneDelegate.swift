//
//  CarPlaySceneDelegate.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import CarPlay
import Combine
import FRadioPlayer
import IdentifiedCollections
import PlayolaCore
import Sharing

@MainActor
class CarPlaySceneDelegate: UIResponder, @preconcurrency CPTemplateApplicationSceneDelegate {
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

  var trackingService = TrackingService.shared

  private var isTransitioningToNowPlaying = false

  var stationPlayer: StationPlayer { StationPlayer.shared }

  override init() {
    super.init()
    setupNowPlayingTemplate()
    observePlaybackErrors()
  }

  private func playStation(_ station: RadioStation?) {
    guard let station else { return }

    stationPlayer.play(station: station)
    showNowPlayingTemplate()
  }

  private func sectionFromStations(_ stations: [RadioStation]) -> CPListSection {
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

  func templateApplicationScene(
    _ scene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    trackingService.reportEvent(.carplayInitialized)
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
    self.interfaceController?.setRootTemplate(tabBarTemplate, animated: true, completion: nil)
  }

  func templateApplicationScene(
    _ scene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    self.interfaceController = nil

    for observer in observers {
      observer.cancel()
    }
    observers.removeAll()
    CPListItem.clearImageCache()
  }

  private func showNowPlayingTemplate(animated: Bool = true) {
    guard let interfaceController = interfaceController else {
      print("No interface controller available")
      return
    }

    // Prevent overlapping transitions
    guard !isTransitioningToNowPlaying else {
      print("Already transitioning to now playing, ignoring")
      return
    }

    defer { isTransitioningToNowPlaying = false }
    isTransitioningToNowPlaying = true

    print("showNowPlayingTemplate called")
    print("Current top template: \(interfaceController.topTemplate)")
    print("Templates in stack: \(interfaceController.templates.count)")
    print(
      "Now playing template in stack: \(interfaceController.templates.contains(CPNowPlayingTemplate.shared))"
    )

    // Don't do anything if already showing
    if interfaceController.topTemplate == CPNowPlayingTemplate.shared {
      print("Already showing now playing template, returning")
      return
    }

    // Check if it's already in the stack
    if interfaceController.templates.contains(CPNowPlayingTemplate.shared) {
      print("Now playing template in stack, popping to it")
      interfaceController.pop(to: CPNowPlayingTemplate.shared, animated: animated) {
        _, error in
        if let error = error {
          print("Error popping to now playing template: \(error)")
        } else {
          print("Successfully popped to now playing template")
        }
      }
    } else {
      print("Pushing now playing template to stack")
      interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: animated) {
        _, error in
        if let error = error {
          print("Error pushing now playing template: \(error)")
        } else {
          print("Successfully pushed now playing template")
        }
      }
    }
  }

  private func setupNowPlayingTemplate() {
    _ = NowPlayingUpdater.shared
  }

  private func observePlaybackErrors() {
    stationPlayer.$state
      .sink { [weak self] state in
        guard let self = self else { return }

        switch state.playbackStatus {
        case .error:
          self.handlePlaybackError()
        case .loading, .startingNewStation:
          self.handleStationLoading()
        case .playing:
          break
        case .stopped:
          self.handleStationStopped()
        default:
          break
        }
      }
      .store(in: &observers)
  }

  private func handleStationLoading() {
    guard let interfaceController = interfaceController else { return }

    // 1) Dismiss any alerts
    if let presentedTemplate = interfaceController.presentedTemplate {
      print("Dismissing presented template: \(presentedTemplate)")
      interfaceController.dismissTemplate(animated: true) { _, error in
        if let error = error {
          print("Error dismissing template: \(error)")
        }
      }
    }

    // 2) If the now playing template is showing, do nothing
    if interfaceController.topTemplate == CPNowPlayingTemplate.shared {
      print("Now playing template already showing, no action needed")
      return
    }

    // 3) If there is a nowplaying template on the stack, pop to it
    if interfaceController.templates.contains(CPNowPlayingTemplate.shared) {
      print("Now playing template in stack, popping to it")
      interfaceController.pop(to: CPNowPlayingTemplate.shared, animated: true) { _, error in
        if let error = error {
          print("Error popping to now playing template: \(error)")
        } else {
          print("Successfully popped to now playing template")
        }
      }
    } else {
      // 4) If there is no nowplaying template on the stack, push to it
      print("Pushing now playing template to stack")
      interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) {
        _, error in
        if let error = error {
          print("Error pushing now playing template: \(error)")
        } else {
          print("Successfully pushed now playing template")
        }
      }
    }
  }

  private func handleStationStopped() {
    guard let interfaceController = interfaceController else { return }

    // If Now Playing template is in the stack, remove it by popping back to root
    if interfaceController.templates.contains(CPNowPlayingTemplate.shared) {
      print("Station stopped - removing now playing template from stack")
      interfaceController.popToRootTemplate(animated: true) { _, error in
        if let error = error {
          print("Error popping to root after stop: \(error)")
        } else {
          print("Successfully removed now playing template after stop")
        }
      }
    } else {
      print("Station stopped - now playing template not in stack")
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
    guard let interfaceController = interfaceController else { return }

    // First dismiss any presented alert
    if interfaceController.presentedTemplate != nil {
      interfaceController.dismissTemplate(animated: true) { _, error in
        if let error = error {
          print("Error dismissing template: \(error)")
        }
      }
    }

    // If we're not already at the root, pop to it
    if interfaceController.templates.count > 1 {
      interfaceController.popToRootTemplate(animated: true) { _, error in
        if let error = error {
          print("Error popping to root: \(error)")
        }
      }
    }
  }

  /// Creates a CPListItem from a RadioStation
  /// - Parameter station: The radio station to convert
  /// - Returns: A configured CPListItem
  public func cPListItemFrom(station: RadioStation) -> CPListItem {
    // Use a default placeholder image for better UX
    let placeholder = UIImage(systemName: "radio") ?? UIImage()

    let listItem = CPListItem(
      text: station.name,
      detailText: station.desc,
      remoteImageUrl: URL(string: station.imageURL),
      placeholder: placeholder
    )
    listItem.handler = { _, completion in
      self.stationPlayer.play(station: station)
      completion()
    }
    return listItem
  }
}

extension CarPlaySceneDelegate: @preconcurrency CPTabBarTemplateDelegate {
  func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
    // Handle tab selection
  }
}

extension CarPlaySceneDelegate: @preconcurrency CPInterfaceControllerDelegate {
  func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template will appear
  }

  func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template did appear
  }

  func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template will disappear
  }

  func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    // Handle template did disappear
  }
}
