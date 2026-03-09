//
//  MainContainerNavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import Dependencies
import Sharing
import SwiftUI

enum AppMode: Equatable {
  case listening
  case broadcasting(stationId: String)
}

/// This class coordinates any ViewControllers that need to be pushed onto the
/// top stack, meaning they will be presented over the MainContainer, covering the
/// tabs.
@Observable
final class MainContainerNavigationCoordinator: Sendable {
  // Per-tab navigation paths
  var homePath: [Path] = []
  var stationsPath: [Path] = []
  var rewardsPath: [Path] = []
  var profilePath: [Path] = []
  var broadcastPath: [Path] = []
  var libraryPath: [Path] = []
  var listenersPath: [Path] = []
  var settingsPath: [Path] = []

  var presentedSheet: PlayolaSheet?
  var appMode: AppMode = .listening

  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  /// Returns a binding-compatible path for the current active tab
  var path: [Path] {
    get {
      switch activeTab {
      case .home: return homePath
      case .stationsList: return stationsPath
      case .rewards: return rewardsPath
      case .profile: return profilePath
      case .broadcast: return broadcastPath
      case .library: return libraryPath
      case .listeners: return listenersPath
      case .settings: return settingsPath
      }
    }
    set {
      switch activeTab {
      case .home: homePath = newValue
      case .stationsList: stationsPath = newValue
      case .rewards: rewardsPath = newValue
      case .profile: profilePath = newValue
      case .broadcast: broadcastPath = newValue
      case .library: libraryPath = newValue
      case .listeners: listenersPath = newValue
      case .settings: settingsPath = newValue
      }
    }
  }

  enum Path: Hashable, Equatable {
    case editProfilePage(EditProfilePageModel)
    case likedSongsPage(LikedSongsPageModel)
    case broadcastPage(BroadcastPageModel)
    case chooseStationToBroadcastPage(ChooseStationToBroadcastPageModel)
    case chooseStationPage(ChooseStationPageModel)
    case askQuestionPage(AskQuestionPageModel)
    case notificationsSettingsPage(NotificationsSettingsPageModel)
    case seriesListPage(SeriesListPageModel)
    case supportPage(SupportPageModel)
    case conversationListPage(ConversationListPageModel)
    case listenerQuestionDetailPage(ListenerQuestionDetailPageModel)

    @MainActor @ViewBuilder
    var destinationView: some View {
      switch self {
      case .editProfilePage(let model):
        EditProfilePageView(model: model)
      case .likedSongsPage(let model):
        LikedSongsPage(model: model)
      case .broadcastPage(let model):
        BroadcastPageView(model: model)
      case .chooseStationToBroadcastPage(let model):
        ChooseStationToBroadcastPageView(model: model)
      case .chooseStationPage(let model):
        ChooseStationPageView(model: model)
      case .askQuestionPage(let model):
        AskQuestionPageView(model: model)
      case .notificationsSettingsPage(let model):
        NotificationsSettingsPageView(model: model)
      case .seriesListPage(let model):
        SeriesListPage(model: model)
      case .supportPage(let model):
        SupportPageView(model: model)
      case .conversationListPage(let model):
        ConversationListPageView(model: model)
      case .listenerQuestionDetailPage(let model):
        ListenerQuestionDetailPageView(model: model)
      }
    }
  }

  func push(_ path: Path) {
    self.path.append(path)
  }

  func pop() {
    _ = self.path.popLast()
  }

  func popToRoot() {
    self.path.removeAll()
  }

  func switchToBroadcastMode(stationId: String) {
    clearAllPaths()
    appMode = .broadcasting(stationId: stationId)
  }

  func switchToListeningMode() {
    clearAllPaths()
    appMode = .listening
  }

  private func clearAllPaths() {
    homePath = []
    stationsPath = []
    rewardsPath = []
    profilePath = []
    broadcastPath = []
    libraryPath = []
    listenersPath = []
    settingsPath = []
  }

  func replace(with path: Path) {
    self.path = [path]
  }

  @MainActor
  func navigateToLikedSongs() async {
    // If in broadcast mode, switch to listening first
    if case .broadcasting = appMode {
      switchToListeningMode()
    }

    // Dismiss any presented sheet if needed
    if presentedSheet != nil {
      withAnimation(.easeInOut(duration: 0.3)) {
        presentedSheet = nil
      }

      // Wait for sheet dismissal animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Set active tab to profile if needed
    if activeTab != .profile {
      withAnimation(.easeInOut(duration: 0.3)) {
        $activeTab.withLock { $0 = .profile }
      }

      // Wait for tab transition animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Navigate to liked songs page
    let likedSongsModel = LikedSongsPageModel()
    push(.likedSongsPage(likedSongsModel))
  }

  @MainActor
  func navigateToSupport(_ model: SupportPageModel) async {
    // If in broadcast mode, switch to listening first
    if case .broadcasting = appMode {
      switchToListeningMode()
    }

    // Dismiss any presented sheet if needed
    if presentedSheet != nil {
      withAnimation(.easeInOut(duration: 0.3)) {
        presentedSheet = nil
      }

      // Wait for sheet dismissal animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Set active tab to profile if needed
    if activeTab != .profile {
      withAnimation(.easeInOut(duration: 0.3)) {
        $activeTab.withLock { $0 = .profile }
      }

      // Wait for tab transition animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Navigate to support page
    push(.supportPage(model))
  }
}
