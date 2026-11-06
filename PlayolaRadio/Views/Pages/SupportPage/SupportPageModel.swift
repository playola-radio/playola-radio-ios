//
//  SupportPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class SupportPageModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored @Dependency(\.toast) var toast
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting

  var conversation: Conversation?
  var messages: [Message] = []
  var newMessage: String = ""
  var isLoading = true
  var isSending = false
  var presentedAlert: PlayolaAlert?
  @ObservationIgnored private var completedSendCount = 0
  @ObservationIgnored private var loadGeneration = 0

  var hasExistingMessages: Bool {
    !messages.isEmpty
  }

  var currentUserId: String? {
    auth.currentUser?.id
  }

  var canSend: Bool {
    !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
  }

  func onViewAppeared() async {
    guard let jwt = auth.jwt else { return }

    loadGeneration += 1
    let generation = loadGeneration

    if conversation != nil {
      await refreshMessages()
      isLoading = false
      return
    }

    isLoading = true

    do {
      let response = try await api.getSupportConversation(jwt)
      if let existing = response.conversation {
        conversation = existing
        messages = try await api.getConversationMessages(jwt, existing.id)
        await markAsRead()
      }
    } catch {
      if !Task.isCancelled {
        if !NetworkErrorClassifier.isNetworkError(error) {
          var tags = NetworkErrorClassifier.errorTags(for: error)
          tags["endpoint"] = "getSupportConversation"
          await errorReporting.reportError(error, tags)
        }
        guard generation == loadGeneration else { return }
        await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
      }
    }

    isLoading = false
  }

  func observeRefreshNotifications() async {
    for await _ in NotificationCenter.default.notifications(named: .refreshSupportMessages) {
      await refreshMessages()
    }
  }

  private func markAsRead() async {
    guard let jwt = auth.jwt, let conversationId = conversation?.id else { return }

    do {
      try await api.markConversationRead(jwt, conversationId)
      await pushNotifications.clearSupportBadge()
    } catch {
      // Silently fail - not critical
    }
  }

  func sendMessage() async {
    guard let jwt = auth.jwt, canSend else { return }

    let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    isSending = true
    newMessage = ""

    do {
      if conversation == nil {
        let response = try await api.createSupportConversation(jwt)
        conversation = response.conversation
      }
      guard let conversationId = conversation?.id else {
        throw APIError.dataNotValid
      }
      let message = try await api.sendConversationMessage(jwt, conversationId, messageText)
      completedSendCount += 1
      if !messages.contains(where: { $0.id == message.id }) {
        messages.append(message)
      }
    } catch {
      if newMessage.isEmpty {
        newMessage = messageText
      }
      presentedAlert = .errorSendingMessage
    }

    isSending = false
  }

  func refreshMessages() async {
    guard let jwt = auth.jwt,
      let conversationId = conversation?.id
    else { return }

    do {
      var fetchedMessages: [Message]
      var sendCountBeforeFetch: Int
      repeat {
        sendCountBeforeFetch = completedSendCount
        fetchedMessages = try await api.getConversationMessages(jwt, conversationId)
      } while completedSendCount != sendCountBeforeFetch
      messages = fetchedMessages
      await markAsRead()
    } catch {
      // Silently fail on refresh
    }
  }

  func handleScenePhaseChange(_ phase: ScenePhase) async {
    guard phase == .active else { return }
    await refreshMessages()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Contact Us" }
  var messageFieldPlaceholder: String { "Message" }
  var sendButtonAccessibilityLabel: String { "Send message" }
  var loadErrorMessage: String { "The conversation couldn't load." }
}

extension PlayolaAlert {
  static var errorLoadingConversation: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load conversation. Please try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static var errorSendingMessage: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Failed to send message. Please try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static var messageSentSuccess: PlayolaAlert {
    PlayolaAlert(
      title: "Thank You!",
      message: "We'll respond as soon as we can!",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
