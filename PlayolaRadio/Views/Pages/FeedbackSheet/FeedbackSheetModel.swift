//
//  FeedbackSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class FeedbackSheetModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Dependency(\.api) var api

  let conversation: Conversation
  let title: String
  let placeholderText: String
  var message: String
  var isSending = false
  var presentedAlert: PlayolaAlert?
  var onSuccess: (() -> Void)?

  static let defaultTitle = "Send us a message and we'll get back to you as soon as we can!"
  static let defaultPlaceholderText = """
    Found a bug?
    Have an idea for a new feature?
    Just want to say hi to the team?

    We would LOVE to hear from you for any reason at all...
    """

  var canSend: Bool {
    !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
  }

  init(
    conversation: Conversation,
    title: String = defaultTitle,
    message: String = "",
    placeholderText: String = defaultPlaceholderText,
    onSuccess: (() -> Void)? = nil
  ) {
    self.conversation = conversation
    self.title = title
    self.message = message
    self.placeholderText = placeholderText
    self.onSuccess = onSuccess
  }

  func send() async {
    guard let jwt = auth.jwt, canSend else { return }

    let messageText = message.trimmingCharacters(in: .whitespacesAndNewlines)
    isSending = true

    do {
      _ = try await api.sendConversationMessage(jwt, conversation.id, messageText)
      isSending = false
      message = ""
      mainContainerNavigationCoordinator.presentedSheet = nil
      onSuccess?()
    } catch {
      isSending = false
      presentedAlert = .errorSendingMessage
    }
  }

  func cancel() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }
}
