//
//  SupportPageTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/15/26.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import SwiftUI
import XCTest

@testable import PlayolaRadio

@MainActor
final class SupportPageTests: XCTestCase {
  private func makeConversation(id: String) -> Conversation {
    Conversation(
      id: id,
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )
  }

  private func makeMessage(id: String, conversationId: String, senderId: String, text: String)
    -> Message
  {
    Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      message: text,
      createdAt: Date(),
      updatedAt: Date(),
      sender: nil
    )
  }

  func testOnViewAppearedLoadsConversationAndMessages() async {
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

    let testConversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let testMessages = [
      Message(
        id: "msg-1",
        conversationId: "conv-1",
        senderId: "user-1",
        message: "Hello",
        createdAt: Date(),
        updatedAt: Date(),
        sender: nil
      )
    ]

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: testConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in testMessages }
    } operation: {
      SupportPageModel()
    }

    XCTAssertTrue(model.isLoading)
    XCTAssertTrue(model.messages.isEmpty)

    await model.onViewAppeared()

    XCTAssertFalse(model.isLoading)
    XCTAssertEqual(model.conversation?.id, "conv-1")
    XCTAssertEqual(model.messages.count, 1)
    XCTAssertTrue(model.hasExistingMessages)
  }

  func testHasExistingMessagesReturnsFalseWhenEmpty() async {
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

    let testConversation = Conversation(
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
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: testConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    XCTAssertFalse(model.hasExistingMessages)
  }

  func testSendMessageAppendsToMessages() async {
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

    let testConversation = Conversation(
      id: "conv-1",
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: Date(),
      participants: nil
    )

    let newMessage = Message(
      id: "msg-new",
      conversationId: "conv-1",
      senderId: "user-1",
      message: "Test message",
      createdAt: Date(),
      updatedAt: Date(),
      sender: nil
    )

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: testConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.sendConversationMessage = { _, _, _ in newMessage }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()
    model.newMessage = "Test message"

    XCTAssertTrue(model.canSend)

    await model.sendMessage()

    XCTAssertEqual(model.messages.count, 1)
    XCTAssertEqual(model.messages.first?.message, "Test message")
    XCTAssertTrue(model.newMessage.isEmpty)
  }

  func testCanSendReturnsFalseWhenMessageEmpty() {
    let model = SupportPageModel()

    model.newMessage = ""
    XCTAssertFalse(model.canSend)

    model.newMessage = "   "
    XCTAssertFalse(model.canSend)

    model.newMessage = "Hello"
    XCTAssertTrue(model.canSend)
  }

  func testOnViewAppearedDoesNotOverwritePresetConversation() async {
    // Regression test: When navigating from ConversationListPage, the model
    // already has a conversation set. onViewAppeared should NOT overwrite it.
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "admin-1", firstName: "Admin", lastName: "User",
        email: "admin@example.com", profileImageUrl: nil, role: "admin"
      ),
      jwt: "test-jwt"
    )

    let presetConversation = makeConversation(id: "preset-conv-id")
    let wrongConversation = makeConversation(id: "wrong-conv-id")
    let presetMessages = [
      makeMessage(
        id: "preset-msg", conversationId: "preset-conv-id", senderId: "user-1", text: "Preset"
      )
    ]

    let getSupportConversationCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        getSupportConversationCalled.setValue(true)
        return SupportConversationResponse(conversation: wrongConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      SupportPageModel()
    }

    model.conversation = presetConversation
    model.messages = presetMessages
    model.isLoading = false

    await model.onViewAppeared()

    XCTAssertEqual(model.conversation?.id, "preset-conv-id")
    XCTAssertFalse(getSupportConversationCalled.value)
  }

  func testOnViewAppearedRefreshesMessagesWhenConversationAlreadySet() async {
    // Regression test: When navigating to support page with conversation already set,
    // onViewAppeared should still refresh the messages to get any new ones.
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Test", lastName: "User",
        email: "test@example.com", profileImageUrl: nil, role: "user"
      ),
      jwt: "test-jwt"
    )

    let presetConversation = makeConversation(id: "conv-1")
    let oldMessages = [
      makeMessage(
        id: "old-msg", conversationId: "conv-1", senderId: "support-1", text: "Old message")
    ]
    let newMessages = [
      makeMessage(
        id: "old-msg", conversationId: "conv-1", senderId: "support-1", text: "Old message"),
      makeMessage(
        id: "new-msg", conversationId: "conv-1", senderId: "support-1", text: "New message"),
    ]

    let getConversationMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled.setValue(true)
        return newMessages
      }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      SupportPageModel()
    }

    model.conversation = presetConversation
    model.messages = oldMessages
    model.isLoading = false

    await model.onViewAppeared()

    XCTAssertTrue(getConversationMessagesCalled.value)
    XCTAssertEqual(model.messages.count, 2)
    XCTAssertEqual(model.messages.last?.message, "New message")
  }

  func testHandleScenePhaseChangeRefreshesMessagesWhenActive() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Test", lastName: "User",
        email: "test@example.com", profileImageUrl: nil, role: "user"
      ),
      jwt: "test-jwt"
    )

    let conversation = makeConversation(id: "conv-1")
    let updatedMessages = [
      makeMessage(id: "msg-1", conversationId: "conv-1", senderId: "support", text: "New reply")
    ]

    let getConversationMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled.setValue(true)
        return updatedMessages
      }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      SupportPageModel()
    }

    model.conversation = conversation
    model.messages = []

    await model.handleScenePhaseChange(.active)

    XCTAssertTrue(getConversationMessagesCalled.value)
    XCTAssertEqual(model.messages.count, 1)
    XCTAssertEqual(model.messages.first?.message, "New reply")
  }

  func testOnViewAppearedCreatesConversationWhenGetReturnsNil() async {
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

    let createdConversation = makeConversation(id: "created-conv")
    let createCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: nil, unreadCount: 0)
      }
      $0.api.createSupportConversation = { _ in
        createCalled.setValue(true)
        return CreateSupportConversationResponse(
          conversation: createdConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    XCTAssertTrue(createCalled.value)
    XCTAssertEqual(model.conversation?.id, "created-conv")
    XCTAssertFalse(model.isLoading)
  }

  func testOnViewAppearedUsesExistingConversationFromGet() async {
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

    let existingConversation = makeConversation(id: "existing-conv")
    let createCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: existingConversation, unreadCount: 0)
      }
      $0.api.createSupportConversation = { _ in
        createCalled.setValue(true)
        return .mockWith()
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    XCTAssertFalse(createCalled.value)
    XCTAssertEqual(model.conversation?.id, "existing-conv")
  }

  func testHandleScenePhaseChangeDoesNothingWhenNotActive() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Test", lastName: "User",
        email: "test@example.com", profileImageUrl: nil, role: "user"
      ),
      jwt: "test-jwt"
    )

    let conversation = makeConversation(id: "conv-1")

    let getConversationMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled.setValue(true)
        return []
      }
    } operation: {
      SupportPageModel()
    }

    model.conversation = conversation

    await model.handleScenePhaseChange(.background)
    XCTAssertFalse(getConversationMessagesCalled.value)

    await model.handleScenePhaseChange(.inactive)
    XCTAssertFalse(getConversationMessagesCalled.value)
  }
}
