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
  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored var stationPlayer: StationPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
  @ObservationIgnored @Shared(.auth) var auth: Auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.unreadSupportCount) var unreadSupportCount
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  // MARK: - Initialization

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: - Properties

  var disposeBag = Set<AnyCancellable>()
  var presentedAlert: PlayolaAlert?
  var hasScheduledShows = false
  var upcomingQuestionAiring: ListenerQuestionAiring?

  var hasUnreadSupportMessages: Bool {
    unreadSupportCount > 0
  }

  var hasUpcomingQuestionAiring: Bool {
    upcomingQuestionAiring != nil
  }

  var canInviteFriends: Bool {
    guard let totalMSListened = listeningTracker?.totalListenTimeMS, totalMSListened > 0 else {
      return false
    }
    let totalHours = Double(totalMSListened) / 1000.0 / 3600.0
    return totalHours >= 2.0
  }

  var welcomeMessage: String {
    if let currentUser = auth.currentUser {
      return "Welcome, \(currentUser.firstName)"
    } else {
      return "Welcome to Playola"
    }
  }

  var supportMessageTileContent: String {
    let count = unreadSupportCount
    return count == 1 ? "1 New Message" : "\(count) New Messages"
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

  @ObservationIgnored lazy var questionAiringTileModel: NewFeatureTileModel =
    NewFeatureTileModel(
      iconName: "mic.fill",
      isSystemImage: true,
      label: "Listener Questions",
      content: "",
      paragraph: "",
      buttonText: "Invite Friends",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        await self.shareQuestionAiringButtonTapped()
      }
    )

  @ObservationIgnored lazy var inviteFriendsTileModel: NewFeatureTileModel =
    NewFeatureTileModel(
      iconName: "person.2.fill",
      isSystemImage: true,
      label: "Power Listener Reward",
      content: "Invite Your Friends",
      paragraph: "You've unlocked the ability to invite friends to Playola!",
      buttonText: "Invite",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        await self.inviteFriendsButtonTapped()
      }
    )

  // MARK: - User Actions

  func viewAppeared() async {
    updateSupportMessageTile()
    await checkForScheduledShows()
    await checkForUpcomingQuestionAirings()

    guard disposeBag.isEmpty else { return }

    $unreadSupportCount.publisher
      .sink { [weak self] _ in
        self?.updateSupportMessageTile()
      }
      .store(in: &disposeBag)
  }

  func playolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    presentedAlert = showSecretStations ? .secretStationsTurnedOnAlert : .secretStationsHiddenAlert
  }

  func stationTapped(_ station: AnyStation) async {
    await analytics.track(
      .startedStation(
        station: StationInfo(from: station),
        entryPoint: "home_recommendations"
      ))
    stationPlayer.play(station: station)
  }

  // MARK: - View Helpers

  var forYouStations: IdentifiedArrayOf<AnyStation> {
    guard let artistList = stationLists.first(where: { $0.slug == StationList.artistListSlug })
    else {
      return []
    }

    let stations =
      artistList
      .stationItems(includeHidden: showSecretStations, includeComingSoon: true)
      .filter { shouldShowStationItem($0, showSecretStations: showSecretStations) }
      .compactMap { $0.anyStation }

    return IdentifiedArray(uniqueElements: stations)
  }

  func liveStatusForStation(_ stationId: String) -> LiveStatus? {
    liveStations.first { $0.stationId == stationId }?.liveStatus
  }

  // MARK: - Private Helpers

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

  private func checkForUpcomingQuestionAirings() async {
    guard let jwt = auth.jwt else { return }

    do {
      let airings = try await api.getMyListenerQuestionAirings(jwt)
      upcomingQuestionAiring = airings.first
      updateQuestionAiringTile()
    } catch {
      upcomingQuestionAiring = nil
    }
  }

  private func updateSupportMessageTile() {
    supportMessageTileModel.content = supportMessageTileContent
  }

  private func updateQuestionAiringTile() {
    guard let airing = upcomingQuestionAiring else { return }
    let curatorName = airing.station?.curatorName ?? "Station"
    questionAiringTileModel.content = "You're On Air Soon!"
    questionAiringTileModel.paragraph =
      "\(curatorName) picked your question! It will air on \(formattedAirtime(airing.airtime))."
  }

  private func inviteFriendsButtonTapped() async {
    guard let jwt = auth.jwt else { return }

    do {
      let expiresAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
      let referralCode = try await api.getOrCreateReferralCode(jwt, expiresAt)
      let shareUrl = "https://admin-api.playola.fm/ios?code=\(referralCode.code)"
      let shareMessage = "Check out Playola Radio - a new app with music curated by real artists!"

      let shareModel = ShareSheetModel(items: [shareMessage, shareUrl])
      mainContainerNavigationCoordinator.presentedSheet = .share(shareModel)
    } catch {
      presentedAlert = .errorCreatingReferralCode
    }
  }

  private func shareQuestionAiringButtonTapped() async {
    guard let jwt = auth.jwt,
      let airing = upcomingQuestionAiring
    else { return }

    // Expiration is the day after the airing
    let calendar = Calendar.current
    let dayAfterAiring =
      calendar.date(byAdding: .day, value: 1, to: airing.airtime) ?? airing.airtime

    do {
      let referralCode = try await api.getOrCreateReferralCode(jwt, dayAfterAiring)
      let shareUrl = "https://admin-api.playola.fm/ios?code=\(referralCode.code)"

      let shareMessage: String
      if let curatorName = airing.station?.curatorName {
        shareMessage =
          "I'm going to be on \(curatorName)'s radio station tomorrow at 6pm. Here's a link to download the app!"
      } else {
        shareMessage =
          "I'm going to be on an internet radio station tomorrow at 6pm. Here's a link to download the app!"
      }

      let shareModel = ShareSheetModel(items: [shareMessage, shareUrl])
      mainContainerNavigationCoordinator.presentedSheet = .share(shareModel)
    } catch {
      presentedAlert = .errorCreatingReferralCode
    }
  }

  private func formattedAirtime(_ date: Date) -> String {
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEEE"
    let dayOfWeek = dayFormatter.string(from: date)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM d"
    let dateStr = dateFormatter.string(from: date)

    let hourFormatter = DateFormatter()
    hourFormatter.dateFormat = "ha"
    let hour = hourFormatter.string(from: date).lowercased()

    return "\(dayOfWeek) (\(dateStr)) around \(hour)"
  }

  private func navigateToSupportPage() async {
    guard let jwt = auth.jwt else { return }
    do {
      let response = try await api.getSupportConversation(jwt)
      let conversation: Conversation
      if let existing = response.conversation {
        conversation = existing
      } else {
        let createResponse = try await api.createSupportConversation(jwt)
        conversation = createResponse.conversation
      }
      let messages = try await api.getConversationMessages(jwt, conversation.id)
      let model = SupportPageModel()
      model.conversation = conversation
      model.messages = messages
      model.isLoading = false
      await mainContainerNavigationCoordinator.navigateToSupport(model)
    } catch {
      presentedAlert = .errorLoadingConversation
    }
  }

  private func navigateToSeriesListPage() {
    let model = SeriesListPageModel()
    mainContainerNavigationCoordinator.push(.seriesListPage(model))
  }

  private func shouldShowStationItem(_ item: APIStationItem, showSecretStations: Bool) -> Bool {
    guard item.visibility == .comingSoon else { return true }
    guard showSecretStations else { return false }
    return item.station?.active == true
  }
}
