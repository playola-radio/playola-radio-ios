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
@MainActor
@Observable
final class MainContainerNavigationCoordinator {
  // Per-tab navigation paths
  var homePath: [Path] = []
  var stationsPath: [Path] = []
  var yourLibraryPath: [Path] = []
  var profilePath: [Path] = []
  var artistStationPath: [Path] = []
  var artistDashboardPath: [Path] = []
  var settingsPath: [Path] = []

  var presentedSheet: PlayolaSheet?
  var appMode: AppMode = .listening

  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  nonisolated init() {}

  private var isKoozieOnly: Bool {
    listeningTracker?.rewardsProfile.rewardsExperienceType == .koozieOnly
  }

  /// Returns a binding-compatible path for the current active tab
  var path: [Path] {
    get {
      switch activeTab {
      case .home: return homePath
      case .stationsList: return stationsPath
      case .yourLibrary: return yourLibraryPath
      case .profile: return profilePath
      case .artistStation: return artistStationPath
      case .artistDashboard: return artistDashboardPath
      case .settings: return settingsPath
      }
    }
    set {
      switch activeTab {
      case .home: homePath = newValue
      case .stationsList: stationsPath = newValue
      case .yourLibrary: yourLibraryPath = newValue
      case .profile: profilePath = newValue
      case .artistStation: artistStationPath = newValue
      case .artistDashboard: artistDashboardPath = newValue
      case .settings: settingsPath = newValue
      }
    }
  }

  enum Path: Hashable, Equatable {
    case editProfilePage(EditProfilePageModel)
    case likedSongsPage(LikedSongsPageModel)
    case rewardsPage(RewardsPageModel)
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
      case .rewardsPage(let model):
        RewardsPageView(model: model)
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

  /// Pushes the Rewards page unless the user is koozie-only (the route is inert for them —
  /// they have no multi-tier rewards page).
  func pushRewards(_ model: RewardsPageModel) {
    guard !isKoozieOnly else { return }
    push(.rewardsPage(model))
  }

  /// Drops any `.rewardsPage` entries from every tab path. Called when a koozie-only profile
  /// loads so restored nav state / deep links can't surface the legacy Rewards page.
  func sanitizeRewardsRouteForKoozie() {
    guard isKoozieOnly else { return }
    let strip: ([Path]) -> [Path] = { paths in
      paths.filter { path in
        if case .rewardsPage = path { return false }
        return true
      }
    }
    homePath = strip(homePath)
    stationsPath = strip(stationsPath)
    yourLibraryPath = strip(yourLibraryPath)
    profilePath = strip(profilePath)
    artistStationPath = strip(artistStationPath)
    artistDashboardPath = strip(artistDashboardPath)
    settingsPath = strip(settingsPath)
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
    $activeTab.withLock { $0 = .artistDashboard }
  }

  func switchToListeningMode() {
    clearAllPaths()
    appMode = .listening
    $activeTab.withLock { $0 = .home }
  }

  private func clearAllPaths() {
    homePath = []
    stationsPath = []
    yourLibraryPath = []
    profilePath = []
    artistStationPath = []
    artistDashboardPath = []
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

    // Liked songs now live on the Your Library tab; switch to it and reset its
    // stack so the library root (Presets + Liked Songs) is shown.
    yourLibraryPath = []
    if activeTab != .yourLibrary {
      withAnimation(.easeInOut(duration: 0.3)) {
        $activeTab.withLock { $0 = .yourLibrary }
      }

      // Wait for tab transition animation
      try? await clock.sleep(for: .milliseconds(300))
    }
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
