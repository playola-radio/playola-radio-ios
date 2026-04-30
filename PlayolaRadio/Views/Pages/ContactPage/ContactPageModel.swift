//
//  ContactPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class ContactPageModel: ViewModel {
  @ObservationIgnored var stationPlayer: StationPlayer
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  var editProfilePageModel: EditProfilePageModel = EditProfilePageModel()
  var likedSongsPageModel: LikedSongsPageModel = LikedSongsPageModel()
  var notificationsSettingsPageModel: NotificationsSettingsPageModel =
    NotificationsSettingsPageModel()
  var chooseStationToBroadcastPageModel: ChooseStationToBroadcastPageModel?
  var supportPageModel: SupportPageModel?
  var conversationListPageModel: ConversationListPageModel?
  var isCheckingSupport = false
  var presentedAlert: PlayolaAlert?

  var isAdmin: Bool {
    auth.currentUser?.role == "admin"
  }

  private var userStations: [Station] = []

  var stationIdToTransitionTo: String? {
    userStations.first?.id
  }

  var myStationButtonVisible: Bool {
    !userStations.isEmpty && !isInBroadcastMode
  }

  var myStationButtonLabel: String {
    userStations.count > 1 ? "My Stations" : "My Station"
  }

  var name: String {
    return auth.currentUser?.fullName ?? "Anonymous"
  }

  var email: String {
    return auth.currentUser?.email ?? "Unknown"
  }

  var isInBroadcastMode: Bool {
    if case .broadcasting = mainContainerNavigationCoordinator.appMode {
      return true
    }
    return false
  }

  func switchToListeningMode() {
    mainContainerNavigationCoordinator.switchToListeningMode()
  }

  init(
    stationPlayer: StationPlayer? = nil
  ) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  func onViewAppeared() async {
    await loadUserStations()
  }

  private func loadUserStations() async {
    guard let jwt = auth.jwt else { return }
    do {
      userStations = try await api.fetchUserStations(jwt)
    } catch {
      // Silently fail - button will remain hidden
    }
  }

  @MainActor
  func onEditProfileTapped() {
    // TODO: Navigate to edit profile view
    print("Edit profile tapped")
    mainContainerNavigationCoordinator.path.append(.editProfilePage(self.editProfilePageModel))
    print(mainContainerNavigationCoordinator.path)
  }

  @MainActor
  func onLikedSongsTapped() {
    mainContainerNavigationCoordinator.path.append(.likedSongsPage(self.likedSongsPageModel))
  }

  @MainActor
  func onNotificationsTapped() {
    mainContainerNavigationCoordinator.path.append(
      .notificationsSettingsPage(self.notificationsSettingsPageModel))
  }

  @MainActor
  func onMyStationTapped() async {
    guard !userStations.isEmpty else { return }

    if userStations.count == 1, let station = userStations.first {
      mainContainerNavigationCoordinator.switchToBroadcastMode(stationId: station.id)
      await analytics.track(
        .viewedBroadcastScreen(
          stationId: station.id,
          stationName: station.name,
          userName: auth.currentUser?.fullName ?? "Unknown"
        ))
    } else {
      let model = ChooseStationToBroadcastPageModel(stations: userStations)
      chooseStationToBroadcastPageModel = model
      mainContainerNavigationCoordinator.push(.chooseStationToBroadcastPage(model))
    }
  }

  func onLogOutTapped() {
    stationPlayer.stop()
    mainContainerNavigationCoordinator.switchToListeningMode()
    $auth.withLock { $0 = Auth() }
  }

  func callIntoStationButtonTapped() {
    let allPlayolaStations = stationLists.flatMap { $0.playolaStations }
    let model = ChooseStationPageModel(
      stations: allPlayolaStations,
      onStationSelected: { [weak self] station in
        self?.stationSelectedForCallIn(station)
      }
    )
    mainContainerNavigationCoordinator.path.append(.chooseStationPage(model))
  }

  private func stationSelectedForCallIn(_ station: Station) {
    let model = AskQuestionPageModel(station: station)
    mainContainerNavigationCoordinator.path.append(.askQuestionPage(model))
  }

  @MainActor
  func onContactUsTapped() async {
    guard let jwt = auth.jwt else { return }

    isCheckingSupport = true

    // Admin flow: check for multiple conversations
    if isAdmin {
      do {
        let conversations = try await api.getConversations(jwt, "open")

        isCheckingSupport = false

        if conversations.count > 1 {
          // Multiple conversations - show list page
          let model = ConversationListPageModel()
          model.conversations = conversations
          model.isLoading = false
          conversationListPageModel = model
          mainContainerNavigationCoordinator.path.append(.conversationListPage(model))
        } else if let item = conversations.first {
          // Single conversation - go directly to it
          await navigateToConversation(item.conversation, jwt: jwt)
        } else {
          // No conversations - fall through to regular user flow
          await handleRegularUserFlow(jwt: jwt)
        }
      } catch {
        isCheckingSupport = false
        presentedAlert = .errorLoadingConversation
      }
    } else {
      // Regular user flow
      await handleRegularUserFlow(jwt: jwt)
    }
  }

  private func handleRegularUserFlow(jwt: String) async {
    do {
      let response = try await api.getSupportConversation(jwt)

      guard let conversation = response.conversation else {
        isCheckingSupport = false
        let feedbackModel = FeedbackSheetModel { [weak self] in
          self?.presentedAlert = .messageSentSuccess
        }
        mainContainerNavigationCoordinator.presentedSheet = .feedbackSheet(feedbackModel)
        return
      }

      let messages = try await api.getConversationMessages(jwt, conversation.id)

      isCheckingSupport = false

      if messages.isEmpty {
        let feedbackModel = FeedbackSheetModel(conversation: conversation) { [weak self] in
          self?.presentedAlert = .messageSentSuccess
        }
        mainContainerNavigationCoordinator.presentedSheet = .feedbackSheet(feedbackModel)
      } else {
        let model = SupportPageModel()
        model.conversation = conversation
        model.messages = messages
        model.isLoading = false
        supportPageModel = model
        mainContainerNavigationCoordinator.path.append(.supportPage(model))
      }
    } catch {
      isCheckingSupport = false
      presentedAlert = .errorLoadingConversation
    }
  }

  private func navigateToConversation(_ conversation: Conversation, jwt: String) async {
    do {
      let messages = try await api.getConversationMessages(jwt, conversation.id)

      let model = SupportPageModel()
      model.conversation = conversation
      model.messages = messages
      model.isLoading = false
      supportPageModel = model
      mainContainerNavigationCoordinator.path.append(.supportPage(model))
    } catch {
      presentedAlert = .errorLoadingConversation
    }
  }
}
