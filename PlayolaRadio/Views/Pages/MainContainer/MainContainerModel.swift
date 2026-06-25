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
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored @Dependency(\.siriShortcuts) var siriShortcuts
  @ObservationIgnored @Dependency(\.appRating) var appRating
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool = false
  @ObservationIgnored @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker
  @ObservationIgnored @Shared(.welcomeMessageEligible) var welcomeMessageEligible: Bool = false
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.unreadSupportCount) var unreadSupportCount
  @ObservationIgnored @Shared(.isBroadcaster) var isBroadcaster
  @ObservationIgnored @Shared(.appVersionRequirements) var appVersionRequirements
  @ObservationIgnored @Shared(.giveawayParticipations) var giveawayParticipations
  @ObservationIgnored @Shared(.pendingCongratsActions) var pendingCongratsActions

  /// Client-side ceiling for presenting a congrats whose push carried no `congratsExpiresAt`. After
  /// this long past `startedAt` we stop prompting the owner (the schedule slot is almost certainly gone).
  private static let congratsClientCutoff: TimeInterval = 60 * 60

  /// Congrats sheets the owner closed (or finished) this foreground. Prevents the publisher-driven
  /// re-run from immediately re-presenting a just-dismissed sheet. Cleared on each foreground.
  @ObservationIgnored private var dismissedCongratsThisForeground: Set<String> = []

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
  var giveawayCoordinator = GiveawayCoordinator()

  @ObservationIgnored private var toastObservationTask: Task<Void, Never>?

  // Broadcast mode models
  var broadcastPageModel: BroadcastPageModel?
  var libraryPageModel: LibraryPageModel?
  var listenerQuestionPageModel: BroadcastersListenerQuestionPageModel?

  var shouldShowSmallPlayer: Bool = false
  private var hasCheckedRatingPromptThisSession = false

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
        applyStationLists(retrievedStationsLists)
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
    giveawayCoordinator.start()
    observeGiveawayResolutions()
    // The publisher only emits on future changes, and the initial `.active` scene phase may not fire
    // `refreshOnForeground()`, so drain any participation resolved before this point (a prior launch,
    // or a winner push handled before the observer installed).
    await processGiveawayResolutions()

    await fetchBroadcasterStatus()
  }

  /// Re-run the resolution arbiter whenever a participation resolves (tap, backstop, or push). The
  /// `.publisher` fires in `willSet`, so defer to a `Task` — by the time it runs the durable write
  /// has completed and `giveawayParticipations` reflects the new value (not the stale one).
  private func observeGiveawayResolutions() {
    $giveawayParticipations.publisher
      .sink { [weak self] _ in
        Task { await self?.processGiveawayResolutions() }
      }
      .store(in: &cancellables)
    // A `giveaway_winner_pending` push writes a new congrats action; surface its sheet immediately
    // (same willSet → Task deferral rationale as the participations observer above).
    $pendingCongratsActions.publisher
      .sink { [weak self] _ in
        Task { await self?.processGiveawayResolutions() }
      }
      .store(in: &cancellables)
  }

  func refreshOnForeground() async {
    // A new foreground is a fresh chance to prompt: a congrats the owner closed last session
    // re-presents now (if still pending and unexpired).
    dismissedCongratsThisForeground.removeAll()
    do {
      let retrievedStationsLists = try await api.getStations()
      applyStationLists(retrievedStationsLists)
    } catch {
      await analytics.track(
        .apiError(
          endpoint: "getStations",
          error: error.localizedDescription
        ))
    }

    await loadAirings()
    await fetchUnreadSupportCount()
    await giveawayCoordinator.pollNow()
    await processGiveawayResolutions()
  }

  private func applyStationLists(_ lists: IdentifiedArrayOf<StationList>) {
    $stationLists.withLock { $0 = lists }
    siriShortcuts.refreshSuggestions()
  }

  func handleScenePhaseChange(_ phase: ScenePhase) {
    switch phase {
    case .active:
      liveStationsPoller.startPolling()
      giveawayCoordinator.start()
    case .background, .inactive:
      liveStationsPoller.stopPolling()
      giveawayCoordinator.stop()
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
      self.$welcomeMessageEligible.withLock { $0 = rewards.shouldShowWelcomeMessage ?? false }
    } catch let err {
      // TODO: Show inline error state on the listening hours tile (instead of
      // a modal alert) — see PR #272 review. Background tile loads shouldn't
      // interrupt the user with a popup. The same pattern is needed for
      // loadAirings and fetchUnreadSupportCount.
      await analytics.track(
        .apiError(
          endpoint: "getRewardsProfile",
          error: err.localizedDescription
        ))
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
      self.mainContainerNavigationCoordinator.presentedSheet = .player(makePlayerModel())
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
    Task {
      let feedbackModel = FeedbackSheetModel(
        title: "Would you be up for letting us know what we can do better?",
        placeholderText: "",
        onSuccess: { [weak self] in
          self?.presentedAlert = .thankYouForFeedback
        }
      )
      await analytics.track(.feedbackSheetPresented)
      mainContainerNavigationCoordinator.presentedSheet = .feedbackSheet(feedbackModel)
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
    self.mainContainerNavigationCoordinator.presentedSheet = .player(makePlayerModel())
  }

  /// Builds the player model and wires the giveaway overlay's tap to the coordinator's real tap.
  private func makePlayerModel() -> PlayerPageModel {
    let model = PlayerPageModel(onDismiss: { [weak self] in
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    })
    model.giveawayOverlayModel.onTap = { [weak self] event in
      try await self?.giveawayCoordinator.tap(event: event)
    }
    model.giveawayOverlayModel.onError = { [weak self] _ in
      self?.presentedAlert = .giveawayTapFailed
    }
    return model
  }

  // MARK: - Giveaway Resolution Presentation

  /// The single app-wide consumer of resolved giveaway participations. The coordinator and push
  /// handler only mutate `@Shared(.giveawayParticipations)`; this turns those durable facts into a
  /// winner sheet (once per win) or a one-time consolation toast. Idempotent — safe to call on every
  /// dict change and on foreground.
  func processGiveawayResolutions() async {
    presentPendingGiveawayWinnerIfNeeded()
    await fireGiveawayLossToastIfNeeded()
    // Winner sheet wins the stage: if the call above presented one, this sees a non-empty/-player
    // sheet and defers the congrats to the next foreground.
    presentPendingCongratsIfNeeded()
  }

  private func presentPendingGiveawayWinnerIfNeeded() {
    // Only take over an empty stage or the player (the immediate-win context). Never clobber another
    // modal flow (feedback, redeem, welcome, …); those defer the win to the next foreground.
    switch mainContainerNavigationCoordinator.presentedSheet {
    case .none, .player: break
    default: return
    }
    // Gate on the unclaimed prize, NOT on whether we've presented before: a winner who dismisses the
    // sheet without submitting (or backgrounds before claiming) must get it back on the next
    // foreground. The early-return above prevents a re-present loop while the sheet is up.
    let pending = giveawayParticipations.values
      .filter {
        guard case .resolvedWon(let submissionCompleted) = $0.status else { return false }
        return !submissionCompleted
      }
      .sorted { $0.tappedAt < $1.tappedAt }
    guard let winner = pending.first else { return }
    let model = GiveawayWinnerSheetModel(
      participation: winner,
      onClose: { [weak self] in self?.dismissGiveawayWinnerSheet() })
    $giveawayParticipations.withLock {
      if $0[winner.id]?.winnerSheetPresentedAt == nil {
        $0[winner.id]?.winnerSheetPresentedAt = now
      }
    }
    mainContainerNavigationCoordinator.presentedSheet = .giveawayWinner(model)
  }

  private func fireGiveawayLossToastIfNeeded() async {
    // The one-time toast is the GUARANTEED loss feedback ("toast everywhere"); the in-player reveal
    // is a bonus while the player is open. Firing it unconditionally means a loser never misses
    // feedback even if the reveal collapses at song-end.
    let pending = giveawayParticipations.values
      .filter {
        guard case .resolvedLost(let toastShown) = $0.status else { return false }
        return !toastShown
      }
      .sorted { $0.tappedAt < $1.tappedAt }
    guard let loss = pending.first else { return }
    $giveawayParticipations.withLock { $0[loss.id]?.status = .resolvedLost(toastShown: true) }
    await toast.show(
      PlayolaToast(
        message: "You were listener #\(loss.tapNumber) — good luck next time!", buttonTitle: ""))
  }

  private func dismissGiveawayWinnerSheet() {
    if case .giveawayWinner = mainContainerNavigationCoordinator.presentedSheet {
      mainContainerNavigationCoordinator.presentedSheet = nil
    }
  }

  // MARK: - Artist Congrats Presentation

  /// Presents the most-urgent pending congrats (owner side) when the stage is clear. Lower priority
  /// than the winner sheet and unrelated modals, and never re-prompts a sheet dismissed this
  /// foreground.
  private func presentPendingCongratsIfNeeded() {
    switch mainContainerNavigationCoordinator.presentedSheet {
    case .none, .player: break
    default: return
    }
    let candidate = pendingCongratsActions.values
      .filter { !$0.isTerminal }
      .filter { !dismissedCongratsThisForeground.contains($0.eventId) }
      .filter { !isCongratsExpired($0) }
      .sorted(by: Self.congratsIsMoreUrgent)
      .first
    guard let action = candidate else { return }
    let model = GiveawayCongratsSheetModel(
      action: action,
      onClose: { [weak self] in self?.dismissGiveawayCongratsSheet(eventId: action.eventId) })
    mainContainerNavigationCoordinator.presentedSheet = .giveawayCongrats(model)
  }

  private func dismissGiveawayCongratsSheet(eventId: String) {
    // Suppress re-presentation for the rest of this foreground (the action may still be non-terminal
    // if the owner closed without sending). A future foreground clears this and re-prompts.
    dismissedCongratsThisForeground.insert(eventId)
    if case .giveawayCongrats = mainContainerNavigationCoordinator.presentedSheet {
      mainContainerNavigationCoordinator.presentedSheet = nil
    }
  }

  private func isCongratsExpired(_ action: CongratsAction) -> Bool {
    let cutoff =
      action.congratsExpiresAt ?? action.startedAt.addingTimeInterval(Self.congratsClientCutoff)
    return now >= cutoff
  }

  /// Soonest expiry first; nil-expiry actions sort last; `startedAt` breaks ties.
  private static func congratsIsMoreUrgent(_ lhs: CongratsAction, _ rhs: CongratsAction) -> Bool {
    switch (lhs.congratsExpiresAt, rhs.congratsExpiresAt) {
    case (let left?, let right?):
      return left == right ? lhs.startedAt < rhs.startedAt : left < right
    case (nil, _?): return false
    case (_?, nil): return true
    case (nil, nil): return lhs.startedAt < rhs.startedAt
    }
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
    toastObservationTask?.cancel()
    toastObservationTask = Task { [weak self] in
      guard let stream = self?.toast.stream() else { return }
      for await toast in stream {
        guard !Task.isCancelled else { return }
        self?.presentedToast = toast
      }
    }
  }

  deinit {
    toastObservationTask?.cancel()
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

  static var giveawayTapFailed: PlayolaAlert {
    PlayolaAlert(
      title: "Tap Didn't Go Through",
      message: "Something went wrong tapping in. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
