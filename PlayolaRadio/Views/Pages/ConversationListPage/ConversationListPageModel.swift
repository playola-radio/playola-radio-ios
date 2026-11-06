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
  private var conversationMutationVersion = 0
  private var readConversationMutationVersions: [String: Int] = [:]

  var showsLoadingIndicator: Bool {
    isLoading && conversations.isEmpty
  }

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
    let fetchMutationVersion = conversationMutationVersion

    do {
      let fetchedConversations = try await api.getConversations(jwt, "open")
      conversations = fetchedConversations.map { fetchedConversation in
        guard
          readConversationMutationVersions[fetchedConversation.id, default: 0]
            > fetchMutationVersion,
          let localConversation = conversations.first(where: { $0.id == fetchedConversation.id }),
          fetchedConversation.conversation.updatedAt <= localConversation.conversation.updatedAt
        else { return fetchedConversation }
        return AdminConversationResponse(
          conversation: fetchedConversation.conversation,
          unreadCountFromOwner: 0
        )
      }
    } catch {
      if !Task.isCancelled {
        presentedAlert = .errorLoadingConversations
      }
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
          conversationMutationVersion += 1
          readConversationMutationVersions[item.id] = conversationMutationVersion
        }
      }
    } catch {
      presentedAlert = .errorLoadingConversation
    }
  }

  func refresh() async {
    await loadConversations()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Support Conversations" }
  var emptyStateMessage: String { "No conversations" }
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
