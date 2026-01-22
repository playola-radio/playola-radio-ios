//
//  SupportPageTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/15/26.
//

import Dependencies
import Foundation
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@MainActor
struct SupportPageTests {
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

  @Test
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

    #expect(model.isLoading == true)
    #expect(model.messages.isEmpty)

    await model.onViewAppeared()

    #expect(model.isLoading == false)
    #expect(model.conversation?.id == "conv-1")
    #expect(model.messages.count == 1)
    #expect(model.hasExistingMessages == true)
  }

  @Test
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

    #expect(model.hasExistingMessages == false)
  }

  @Test
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

    #expect(model.canSend == true)

    await model.sendMessage()

    #expect(model.messages.count == 1)
    #expect(model.messages.first?.message == "Test message")
    #expect(model.newMessage.isEmpty)
  }

  @Test
  func testCanSendReturnsFalseWhenMessageEmpty() {
    let model = SupportPageModel()

    model.newMessage = ""
    #expect(model.canSend == false)

    model.newMessage = "   "
    #expect(model.canSend == false)

    model.newMessage = "Hello"
    #expect(model.canSend == true)
  }

  @Test
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

    var getSupportConversationCalled = false

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        getSupportConversationCalled = true
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

    #expect(model.conversation?.id == "preset-conv-id")
    #expect(getSupportConversationCalled == false)
  }

  @Test
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

    var getConversationMessagesCalled = false

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled = true
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

    #expect(getConversationMessagesCalled == true)
    #expect(model.messages.count == 2)
    #expect(model.messages.last?.message == "New message")
  }

  @Test
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

    var getConversationMessagesCalled = false

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled = true
        return updatedMessages
      }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      SupportPageModel()
    }

    model.conversation = conversation
    model.messages = []

    await model.handleScenePhaseChange(.active)

    #expect(getConversationMessagesCalled == true)
    #expect(model.messages.count == 1)
    #expect(model.messages.first?.message == "New reply")
  }

  @Test
  func testHandleScenePhaseChangeDoesNothingWhenNotActive() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Test", lastName: "User",
        email: "test@example.com", profileImageUrl: nil, role: "user"
      ),
      jwt: "test-jwt"
    )

    let conversation = makeConversation(id: "conv-1")

    var getConversationMessagesCalled = false

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled = true
        return []
      }
    } operation: {
      SupportPageModel()
    }

    model.conversation = conversation

    await model.handleScenePhaseChange(.background)
    #expect(getConversationMessagesCalled == false)

    await model.handleScenePhaseChange(.inactive)
    #expect(getConversationMessagesCalled == false)
  }
}
