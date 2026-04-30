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

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(
    conversation: Conversation? = nil,
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

  // MARK: - Properties

  var conversation: Conversation?
  let title: String
  let placeholderText: String
  var message: String
  var isSending = false
  var presentedAlert: PlayolaAlert?
  var onSuccess: (() -> Void)?

  let navigationTitle = "Contact Us"
  let sendButtonText = "Send Message"
  let cancelButtonText = "Cancel"

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

  // MARK: - User Actions

  func sendButtonTapped() async {
    guard let jwt = auth.jwt, canSend else { return }

    let messageText = message.trimmingCharacters(in: .whitespacesAndNewlines)
    isSending = true

    do {
      if conversation == nil {
        let response = try await api.createSupportConversation(jwt)
        conversation = response.conversation
      }
      guard let conversationId = conversation?.id else {
        throw APIError.dataNotValid
      }
      _ = try await api.sendConversationMessage(jwt, conversationId, messageText)
      isSending = false
      message = ""
      mainContainerNavigationCoordinator.presentedSheet = nil
      onSuccess?()
    } catch {
      isSending = false
      presentedAlert = .errorSendingMessage
    }
  }

  func cancelButtonTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }
}
