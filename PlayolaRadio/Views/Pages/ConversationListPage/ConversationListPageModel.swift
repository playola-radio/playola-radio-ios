//
//  ConversationListPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class ConversationListPageModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Dependency(\.api) var api

  var conversations: [AdminConversationResponse] = []
  var isLoading = true
  var presentedAlert: PlayolaAlert?

  /// Conversations sorted with unread first, then by most recent
  var sortedConversations: [AdminConversationResponse] {
    conversations.sorted { first, second in
      // Unread conversations first
      if first.unreadCountFromOwner > 0 && second.unreadCountFromOwner == 0 {
        return true
      }
      if first.unreadCountFromOwner == 0 && second.unreadCountFromOwner > 0 {
        return false
      }
      // Then by most recently updated
      return first.conversation.updatedAt > second.conversation.updatedAt
    }
  }

  func onViewAppeared() async {
    await loadConversations()
  }

  private func loadConversations() async {
    guard let jwt = auth.jwt else { return }

    isLoading = true

    do {
      conversations = try await api.getConversations(jwt, "open")
    } catch {
      presentedAlert = .errorLoadingConversations
    }

    isLoading = false
  }

  func onConversationTapped(_ item: AdminConversationResponse) async {
    guard let jwt = auth.jwt else { return }

    // Load messages for this conversation
    do {
      let messages = try await api.getConversationMessages(jwt, item.conversation.id)

      let model = SupportPageModel()
      model.conversation = item.conversation
      model.messages = messages
      model.isLoading = false

      mainContainerNavigationCoordinator.path.append(.supportPage(model))

      // Mark as read if there are unread messages
      if item.unreadCountFromOwner > 0 {
        try? await api.markConversationRead(jwt, item.conversation.id)
        // Update local state
        if let index = conversations.firstIndex(where: { $0.id == item.id }) {
          conversations[index] = AdminConversationResponse(
            conversation: item.conversation,
            unreadCountFromOwner: 0
          )
        }
      }
    } catch {
      presentedAlert = .errorLoadingConversation
    }
  }

  func refresh() async {
    await loadConversations()
  }
}

extension PlayolaAlert {
  static var errorLoadingConversations: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load conversations. Please try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
