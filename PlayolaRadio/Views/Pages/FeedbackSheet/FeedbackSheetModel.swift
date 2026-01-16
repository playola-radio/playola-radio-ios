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
  var message: String = ""
  var isSending = false
  var presentedAlert: PlayolaAlert?
  var onSuccess: (() -> Void)?

  var canSend: Bool {
    !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
  }

  init(conversation: Conversation, onSuccess: (() -> Void)? = nil) {
    self.conversation = conversation
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
