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
    defer {
      if generation == loadGeneration { isLoading = false }
    }

    var endpoint = conversation == nil ? "getSupportConversation" : "getConversationMessages"

    do {
      if let conversation {
        try await loadMessages(jwt: jwt, conversationId: conversation.id)
      } else {
        isLoading = true
        let response = try await api.getSupportConversation(jwt)
        if let existing = response.conversation {
          conversation = existing
          endpoint = "getConversationMessages"
          try await loadMessages(jwt: jwt, conversationId: existing.id)
        }
      }
    } catch {
      if !Task.isCancelled {
        if !NetworkErrorClassifier.isNetworkError(error) {
          var tags = NetworkErrorClassifier.errorTags(for: error)
          tags["endpoint"] = endpoint
          await errorReporting.reportError(error, tags)
        }
        guard generation == loadGeneration else { return }
        guard !Task.isCancelled else { return }
        await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
      }
    }

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
      await reportUnexpectedError(error, endpoint: "markConversationRead")
    }
  }

  func sendMessage() async {
    guard let jwt = auth.jwt, canSend else { return }

    let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    isSending = true
    newMessage = ""
    var endpoint = "createSupportConversation"

    do {
      if conversation == nil {
        let response = try await api.createSupportConversation(jwt)
        conversation = response.conversation
      }
      guard let conversationId = conversation?.id else {
        throw APIError.dataNotValid
      }
      endpoint = "sendConversationMessage"
      let message = try await api.sendConversationMessage(jwt, conversationId, messageText)
      completedSendCount += 1
      if !messages.contains(where: { $0.id == message.id }) {
        messages.append(message)
      }
    } catch {
      if newMessage.isEmpty {
        newMessage = messageText
      } else {
        newMessage = messageText + "\n" + newMessage
      }
      presentedAlert = .errorSendingMessage
      await reportUnexpectedError(error, endpoint: endpoint)
    }

    isSending = false
  }

  func refreshMessages() async {
    guard let jwt = auth.jwt,
      let conversationId = conversation?.id
    else { return }

    do {
      try await loadMessages(jwt: jwt, conversationId: conversationId)
    } catch {
      guard !Task.isCancelled, !(error is CancellationError) else { return }
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "getConversationMessages"
        await errorReporting.reportError(error, tags)
      }
    }
  }

  func handleScenePhaseChange(_ phase: ScenePhase) async {
    guard phase == .active else { return }
    await refreshMessages()
  }

  private func loadMessages(jwt: String, conversationId: String) async throws {
    var fetchedMessages: [Message]
    var sendCountBeforeFetch: Int
    repeat {
      sendCountBeforeFetch = completedSendCount
      fetchedMessages = try await api.getConversationMessages(jwt, conversationId)
    } while completedSendCount != sendCountBeforeFetch
    var seenIds = Set<String>()
    messages = fetchedMessages.filter { seenIds.insert($0.id).inserted }
    await markAsRead()
  }

  private func reportUnexpectedError(_ error: Error, endpoint: String) async {
    guard !Task.isCancelled, !(error is CancellationError),
      !NetworkErrorClassifier.isNetworkError(error)
    else { return }
    var tags = NetworkErrorClassifier.errorTags(for: error)
    tags["endpoint"] = endpoint
    await errorReporting.reportError(error, tags)
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
