//
//  MainContainerModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//

import Combine
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class MainContainerModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.toast) var toast
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored @Dependency(\.appRating) var appRating
  @ObservationIgnored var stationPlayer: StationPlayer!
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool = false
  @ObservationIgnored @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.unreadSupportCount) var unreadSupportCount
  @ObservationIgnored @Shared(.isBroadcaster) var isBroadcaster
  @ObservationIgnored @Shared(.appVersionRequirements) var appVersionRequirements

  enum ActiveTab {
    // Listening mode tabs
    case home
    case stationsList
    case rewards
    case profile
    // Broadcast mode tabs
    case broadcast
    case library
    case listeners
    case settings
  }

  var presentedAlert: PlayolaAlert?
  var presentedToast: PlayolaToast?

  var homePageModel = HomePageModel()
  var stationListModel = StationListModel()
  var rewardsPageModel = RewardsPageModel()
  var contactPageModel = ContactPageModel()
  var liveStationsPoller = LiveStationsPoller()

  // Broadcast mode models
  var broadcastPageModel: BroadcastPageModel?
  var libraryPageModel: LibraryPageModel?
  var listenerQuestionPageModel: BroadcastersListenerQuestionPageModel?

  var shouldShowSmallPlayer: Bool = false
  private var hasCheckedRatingPromptThisSession = false

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    super.init()
  }

  // MARK: - Mode-Aware Properties

  var isInBroadcastMode: Bool {
    if case .broadcasting = mainContainerNavigationCoordinator.appMode {
      return true
    }
    return false
  }

  var broadcastStationId: String? {
    if case .broadcasting(let stationId) = mainContainerNavigationCoordinator.appMode {
      return stationId
    }
    return nil
  }

  func ensureBroadcastModels() {
    guard let stationId = broadcastStationId else { return }
    if broadcastPageModel?.stationId != stationId {
      broadcastPageModel = BroadcastPageModel(stationId: stationId)
    }
    if libraryPageModel?.stationId != stationId {
      libraryPageModel = LibraryPageModel(stationId: stationId)
    }
    if listenerQuestionPageModel?.stationId != stationId {
      listenerQuestionPageModel = BroadcastersListenerQuestionPageModel(stationId: stationId)
    }
  }

  func viewAppeared() async {
    // Register for remote notifications (user is now logged in)
    await pushNotifications.registerForRemoteNotifications()

    // Load station lists if not already loaded
    if !stationListsLoaded {
      do {
        let retrievedStationsLists = try await api.getStations()
        self.$stationLists.withLock { $0 = retrievedStationsLists }
        self.$stationListsLoaded.withLock { $0 = true }
      } catch {
        presentedAlert = .errorLoadingStations
        await analytics.track(
          .apiError(
            endpoint: "getStations",
            error: error.localizedDescription
          ))
      }
    }

    await fetchUnreadSupportCount()

    // NOTE: For now, this has to stay connected to the Singleton in order to avoid reloading
    // the entire app every time a nowPlaying.publisher event is received.  That seems to be
    // what happens when we use the Shared nowPlaying value.  In the future we should figure out
    // how to get this to work with the nowPlaying shared state.
    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)

    observeToasts()

    await loadListeningTracker()
    await loadAirings()

    liveStationsPoller.startPolling()

    await fetchBroadcasterStatus()
  }

  func refreshOnForeground() async {
    do {
      let retrievedStationsLists = try await api.getStations()
      self.$stationLists.withLock { $0 = retrievedStationsLists }
    } catch {
      await analytics.track(
        .apiError(
          endpoint: "getStations",
          error: error.localizedDescription
        ))
    }

    await loadAirings()
    await fetchUnreadSupportCount()
  }

  func handleScenePhaseChange(_ phase: ScenePhase) {
    switch phase {
    case .active:
      liveStationsPoller.startPolling()
    case .background, .inactive:
      liveStationsPoller.stopPolling()
    @unknown default:
      break
    }
  }

  func loadAirings() async {
    guard let token = auth.jwt else { return }
    do {
      let fetchedAirings = try await api.getAirings(token, nil)
      $airings.withLock { $0 = IdentifiedArray(uniqueElements: fetchedAirings) }
    } catch {
      await analytics.track(
        .apiError(
          endpoint: "getAirings",
          error: error.localizedDescription
        ))
    }
  }

  func loadListeningTracker() async {
    guard let authJWT = auth.jwt else {
      print("Error not signed in")
      return
    }
    do {
      let rewards = try await api.getRewardsProfile(authJWT)
      self.$listeningTracker.withLock { $0 = ListeningTracker(rewardsProfile: rewards) }
    } catch let err {
      print(err)
    }
  }

  func fetchUnreadSupportCount() async {
    guard let jwt = auth.jwt else { return }
    do {
      let response = try await api.getSupportConversation(jwt)
      $unreadSupportCount.withLock { $0 = response.unreadCount }
    } catch {
      // Silently fail
    }
  }

  func dismissButtonInSheetTapped() {
    self.mainContainerNavigationCoordinator.presentedSheet = nil
  }

  func processNewStationState(_ newState: StationPlayer.State) {
    switch newState.playbackStatus {
    case .startingNewStation:
      self.mainContainerNavigationCoordinator.presentedSheet = .player(
        PlayerPageModel(onDismiss: {
          self.mainContainerNavigationCoordinator.presentedSheet = nil
        }))
    default: break
    }
    self.setShouldShowSmallPlayer(newState)
  }

  func checkAndShowRatingPromptIfNeeded() {
    guard !hasCheckedRatingPromptThisSession else { return }
    guard let tracker = listeningTracker else { return }

    if appRating.shouldShowRatingPrompt(tracker.totalListenTimeMS) {
      hasCheckedRatingPromptThisSession = true
      showRatingPrompt()
    }
  }

  private func showRatingPrompt() {
    presentedAlert = .ratingPrompt(
      onEnjoying: { [weak self] in
        guard let self else { return }
        await self.analytics.track(.ratingPromptEnjoying)
        self.appRating.markRatingPromptShown()
        await self.appRating.requestAppStoreReview()
      },
      onNotEnjoying: { [weak self] in
        guard let self else { return }
        await self.analytics.track(.ratingPromptNotEnjoying)
        self.appRating.markRatingPromptShown()
        self.appRating.markRatingPromptDismissed()
        self.presentedAlert = nil
        self.showFeedbackSheet()
      },
      onNotNow: { [weak self] in
        guard let self else { return }
        await self.analytics.track(.ratingPromptDismissed)
        self.appRating.markRatingPromptDismissed()
      }
    )
  }

  private func showFeedbackSheet() {
    guard let jwt = auth.jwt else { return }
    Task {
      do {
        let conversation = try await api.getOrCreateSupportConversation(jwt)
        let feedbackModel = FeedbackSheetModel(
          conversation: conversation,
          title: "Would you be up for letting us know what we can do better?",
          placeholderText: "",
          onSuccess: { [weak self] in
            self?.presentedAlert = .thankYouForFeedback
          }
        )
        await analytics.track(.feedbackSheetPresented)
        mainContainerNavigationCoordinator.presentedSheet = .feedbackSheet(feedbackModel)
      } catch {
        await analytics.track(.feedbackSheetFailed(error: error.localizedDescription))
      }
    }
  }

  func setShouldShowSmallPlayer(_ stationPlayerState: StationPlayer.State) {
    withAnimation {
      switch stationPlayerState.playbackStatus {
      case .playing, .startingNewStation, .loading:
        self.shouldShowSmallPlayer = true
      default:
        self.shouldShowSmallPlayer = false
      }
    }
  }

  func onSmallPlayerTapped() {
    self.mainContainerNavigationCoordinator.presentedSheet = .player(
      PlayerPageModel(onDismiss: { self.mainContainerNavigationCoordinator.presentedSheet = nil }))
  }

  // Test method for showing toasts
  func testShowToast() {
    Task {
      await toast.show(
        PlayolaToast(
          message: "Added to Liked Songs",
          buttonTitle: "View all",
          action: {
            print("View all tapped!")
          }
        )
      )
    }
  }

  func fetchBroadcasterStatus() async {
    guard let jwt = auth.jwt else { return }
    do {
      let stations = try await api.fetchUserStations(jwt)
      let wasBroadcaster = isBroadcaster
      $isBroadcaster.withLock { $0 = !stations.isEmpty }

      if !wasBroadcaster, !stations.isEmpty, let requirements = appVersionRequirements,
        let currentVersion = Bundle.main.releaseVersionNumber,
        isVersion(currentVersion, lessThan: requirements.minimumBroadcasterVersion)
      {
        NotificationCenter.default.post(name: .requiresAppUpdate, object: nil)
      }
    } catch {
      // Fail silently — keep existing isBroadcaster value
    }
  }

  func observeToasts() {
    Task { @MainActor in
      while true {
        if let currentToast = await toast.currentToast() {
          self.presentedToast = currentToast
        } else {
          self.presentedToast = nil
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }
}

extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Stations",
      message:
        "There was an error loading the stations. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static var thankYouForFeedback: PlayolaAlert {
    PlayolaAlert(
      title: "Thank You for the Feedback!",
      message:
        "Thank you so much. Someone will get back to you soon.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
