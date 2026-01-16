//
//  FeedbackSheetTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct FeedbackSheetTests {
  @Test
  func testCanSendReturnsFalseWhenMessageEmpty() {
    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let model = FeedbackSheetModel(conversation: conversation)

    model.message = ""
    #expect(model.canSend == false)

    model.message = "   "
    #expect(model.canSend == false)

    model.message = "Hello"
    #expect(model.canSend == true)
  }

  @Test
  func testCanSendReturnsFalseWhenSending() {
    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let model = FeedbackSheetModel(conversation: conversation)
    model.message = "Hello"
    model.isSending = true

    #expect(model.canSend == false)
  }

  @Test
  func testSendClearsMessageAndDismissesSheet() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com",
        profileImageUrl: nil,
        role: "user"
      ),
      jwt: "test-jwt"
    )

    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let sentMessage = Message(
      id: "msg-1",
      conversationId: "conv-1",
      senderId: "user-1",
      message: "Test message",
      createdAt: Date(),
      updatedAt: Date(),
      sender: nil
    )

    let model = withDependencies {
      $0.api.sendConversationMessage = { _, _, _ in sentMessage }
    } operation: {
      FeedbackSheetModel(conversation: conversation)
    }

    navCoordinator.presentedSheet = .feedbackSheet(model)
    model.message = "Test message"

    await model.send()

    #expect(model.message.isEmpty)
    #expect(model.isSending == false)
  }

  @Test
  func testSendCallsOnSuccessCallback() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com",
        profileImageUrl: nil,
        role: "user"
      ),
      jwt: "test-jwt"
    )

    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let sentMessage = Message(
      id: "msg-1",
      conversationId: "conv-1",
      senderId: "user-1",
      message: "Test message",
      createdAt: Date(),
      updatedAt: Date(),
      sender: nil
    )

    var onSuccessCalled = false

    let model = withDependencies {
      $0.api.sendConversationMessage = { _, _, _ in sentMessage }
    } operation: {
      FeedbackSheetModel(conversation: conversation) {
        onSuccessCalled = true
      }
    }

    navCoordinator.presentedSheet = .feedbackSheet(model)
    model.message = "Test message"

    await model.send()

    #expect(onSuccessCalled == true)
  }

  @Test
  func testSendShowsErrorOnFailure() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com",
        profileImageUrl: nil,
        role: "user"
      ),
      jwt: "test-jwt"
    )

    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let model = withDependencies {
      $0.api.sendConversationMessage = { _, _, _ in
        throw APIError.validationError("Failed")
      }
    } operation: {
      FeedbackSheetModel(conversation: conversation)
    }

    model.message = "Test message"

    await model.send()

    #expect(model.presentedAlert == .errorSendingMessage)
    #expect(model.isSending == false)
  }

  @Test
  func testCancelDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let conversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let model = FeedbackSheetModel(conversation: conversation)
    navCoordinator.presentedSheet = .feedbackSheet(model)

    model.cancel()

    #expect(navCoordinator.presentedSheet == nil)
  }
}
