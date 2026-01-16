import Combine
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
//
//  HomePageViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import Sharing
import SwiftUI

@MainActor
@Observable
class HomePageModel: ViewModel {
  var disposeBag = Set<AnyCancellable>()
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
  @ObservationIgnored @Shared(.auth) var auth: Auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.unreadSupportCount) var unreadSupportCount
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  @ObservationIgnored var stationPlayer: StationPlayer

  var forYouStations: IdentifiedArrayOf<AnyStation> = []
  var presentedAlert: PlayolaAlert?
  var hasScheduledShows = false
  var hasUnreadSupportMessages: Bool {
    unreadSupportCount > 0
  }

  var welcomeMessage: String {
    if let currentUser = auth.currentUser {
      return "Welcome, \(currentUser.firstName)"
    } else {
      return "Welcome to Playola"
    }
  }

  @ObservationIgnored lazy var listeningTimeTileModel: ListeningTimeTileModel =
    ListeningTimeTileModel(
      buttonText: "Redeem Your Rewards!",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        await self.analytics.track(.navigatedToRewardsFromListeningTile)
        await self.$activeTab.withLock { $0 = .rewards }
      }
    )

  @ObservationIgnored lazy var scheduledShowsTileModel: NewFeatureTileModel =
    NewFeatureTileModel(
      iconName: "sparkles",
      isSystemImage: true,
      label: "New Feature",
      content: "Radio Shows",
      paragraph:
        "Your favorite artists hosting their own radio shows. Check them out!",
      buttonText: "See Upcoming Shows",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        self.navigateToSeriesListPage()
      }
    )

  var supportMessageTileContent: String {
    let count = unreadSupportCount
    return count == 1 ? "1 New Message" : "\(count) New Messages"
  }

  @ObservationIgnored lazy var supportMessageTileModel: NewFeatureTileModel =
    NewFeatureTileModel(
      iconName: "bubble.left.fill",
      isSystemImage: true,
      label: "Messages",
      content: "",
      paragraph: "You have a message from our support team.",
      buttonText: "View Messages",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        await self.navigateToSupportPage()
      }
    )

  @MainActor
  func updateSupportMessageTile() {
    supportMessageTileModel.content = supportMessageTileContent
  }

  @MainActor
  func navigateToSupportPage() async {
    guard let jwt = auth.jwt else { return }
    do {
      let response = try await api.getSupportConversation(jwt)
      let messages = try await api.getConversationMessages(jwt, response.conversation.id)
      let model = SupportPageModel()
      model.conversation = response.conversation
      model.messages = messages
      model.isLoading = false
      await mainContainerNavigationCoordinator.navigateToSupport(model)
    } catch {
      presentedAlert = .errorLoadingConversation
    }
  }

  @MainActor
  func navigateToSeriesListPage() {
    let model = SeriesListPageModel()
    mainContainerNavigationCoordinator.push(.seriesListPage(model))
  }

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: Actions
  func viewAppeared() async {
    loadForYouStations(lists: stationLists, showSecretStationsNewValue: showSecretStations)
    updateSupportMessageTile()
    await checkForScheduledShows()

    // Only set up subscription once
    guard disposeBag.isEmpty else { return }

    Publishers.CombineLatest(
      $stationLists.publisher,
      $showSecretStations.publisher
    )
    .sink { [weak self] lists, showSecrets in
      self?.loadForYouStations(lists: lists, showSecretStationsNewValue: showSecrets)
    }
    .store(in: &disposeBag)

    $unreadSupportCount.publisher
      .sink { [weak self] _ in
        self?.updateSupportMessageTile()
      }
      .store(in: &disposeBag)
  }

  private func checkForScheduledShows() async {
    guard let jwt = auth.jwt else { return }

    do {
      let airings = try await api.getAirings(jwt, nil)
      let upcomingAirings = airings.filter { airing in
        let durationMS = airing.episode?.durationMS ?? 0
        let endTime = airing.airtime.addingTimeInterval(TimeInterval(durationMS) / 1000.0)
        return endTime > now
      }
      hasScheduledShows = !upcomingAirings.isEmpty
    } catch {
      hasScheduledShows = false
    }
  }

  func handlePlayolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    presentedAlert = showSecretStations ? .secretStationsTurnedOnAlert : .secretStationsHiddenAlert
  }

  func handleStationTapped(_ station: AnyStation) async {
    await analytics.track(
      .startedStation(
        station: StationInfo(from: station),
        entryPoint: "home_recommendations"
      ))
    stationPlayer.play(station: station)
  }

  func liveStatusForStation(_ stationId: String) -> LiveStatus? {
    liveStations.first { $0.stationId == stationId }?.liveStatus
  }

  private func shouldShowStationItem(_ item: APIStationItem, showSecretStations: Bool) -> Bool {
    // Non-coming-soon items pass through (StationList handles hidden visibility)
    guard item.visibility == .comingSoon else { return true }

    // Hide coming soon entries unless the user has unlocked secret stations
    guard showSecretStations else { return false }

    // Only surface coming soon items that have an active Playola station payload
    return item.station?.active == true
  }

  private func loadForYouStations(
    lists: IdentifiedArrayOf<StationList>,
    showSecretStationsNewValue: Bool
  ) {
    guard let artistList = lists.first(where: { $0.slug == StationList.artistListSlug }) else {
      forYouStations = []
      return
    }

    let stations =
      artistList
      .stationItems(includeHidden: showSecretStationsNewValue, includeComingSoon: true)
      // Filter out stations that can't be played
      .filter { shouldShowStationItem($0, showSecretStations: showSecretStationsNewValue) }
      .compactMap { $0.anyStation }

    forYouStations = IdentifiedArray(uniqueElements: stations)
  }
}
