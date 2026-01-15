//
//  SupportPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI
import UserNotifications

@MainActor
@Observable
class SupportPageModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.unreadSupportCount) var unreadSupportCount
  @ObservationIgnored @Dependency(\.api) var api

  var conversation: Conversation?
  var messages: [Message] = []
  var newMessage: String = ""
  var isLoading = true
  var isSending = false
  var presentedAlert: PlayolaAlert?

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
    isLoading = true
    startListeningForRefresh()

    do {
      conversation = try await api.getSupportConversation(jwt)
      if let conversationId = conversation?.id {
        messages = try await api.getConversationMessages(jwt, conversationId)
        await markAsRead()
      }
    } catch {
      presentedAlert = .errorLoadingConversation
    }

    isLoading = false
  }

  private func markAsRead() async {
    guard let jwt = auth.jwt, let conversationId = conversation?.id else { return }

    do {
      try await api.markConversationRead(jwt, conversationId)
      unreadSupportCount = 0
      try? await UNUserNotificationCenter.current().setBadgeCount(0)
    } catch {
      // Silently fail - not critical
    }
  }

  func sendMessage() async {
    guard let jwt = auth.jwt,
      let conversationId = conversation?.id,
      canSend
    else { return }

    let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    isSending = true
    newMessage = ""

    do {
      let message = try await api.sendConversationMessage(jwt, conversationId, messageText)
      messages.append(message)
    } catch {
      newMessage = messageText
      presentedAlert = .errorSendingMessage
    }

    isSending = false
  }

  func refreshMessages() async {
    guard let jwt = auth.jwt,
      let conversationId = conversation?.id
    else { return }

    do {
      messages = try await api.getConversationMessages(jwt, conversationId)
      await markAsRead()
    } catch {
      // Silently fail on refresh
    }
  }

  func startListeningForRefresh() {
    NotificationCenter.default.addObserver(
      forName: .refreshSupportMessages,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.refreshMessages()
      }
    }
  }
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
