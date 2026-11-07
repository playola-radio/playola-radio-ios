//
//  SupportPageTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/15/26.
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
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
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: testConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in testMessages }
    } operation: {
      SupportPageModel()
    }

    #expect(model.isLoading)
    #expect(model.messages.isEmpty)

    await model.onViewAppeared()

    #expect(!model.isLoading)
    #expect(model.conversation?.id == "conv-1")
    #expect(model.messages.count == 1)
    #expect(model.hasExistingMessages)
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
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: testConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    #expect(!model.hasExistingMessages)
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
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
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

    #expect(model.canSend)

    await model.sendMessage()

    #expect(model.messages.count == 1)
    #expect(model.messages.first?.message == "Test message")
    #expect(model.newMessage.isEmpty)
  }

  @Test
  func testCanSendReturnsFalseWhenMessageEmpty() {
    let model = SupportPageModel()

    model.newMessage = ""
    #expect(!model.canSend)

    model.newMessage = "   "
    #expect(!model.canSend)

    model.newMessage = "Hello"
    #expect(model.canSend)
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

    let getSupportConversationCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        getSupportConversationCalled.setValue(true)
        return SupportConversationResponse(conversation: wrongConversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
    } operation: {
      SupportPageModel()
    }

    model.conversation = presetConversation
    model.messages = presetMessages

    await model.onViewAppeared()

    #expect(model.conversation?.id == "preset-conv-id")
    #expect(!getSupportConversationCalled.value)
    #expect(!model.isLoading)
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

    let getConversationMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled.setValue(true)
        return newMessages
      }
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
    } operation: {
      SupportPageModel()
    }

    model.conversation = presetConversation
    model.messages = oldMessages

    await model.onViewAppeared()

    #expect(getConversationMessagesCalled.value)
    #expect(model.messages.count == 2)
    #expect(model.messages.last?.message == "New message")
    #expect(!model.isLoading)
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

    let getConversationMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        getConversationMessagesCalled.setValue(true)
        return updatedMessages
      }
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
    } operation: {
      SupportPageModel()
    }

    model.conversation = conversation
    model.messages = []

    await model.handleScenePhaseChange(.active)

    #expect(getConversationMessagesCalled.value)
    #expect(model.messages.count == 1)
    #expect(model.messages.first?.message == "New reply")
  }

  @Test
  func testOnViewAppearedDoesNotCreateConversationWhenGetReturnsNil() async {
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

    let createCalled = LockIsolated(false)
    let getMessagesCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: nil, unreadCount: 0)
      }
      $0.api.createSupportConversation = { _ in
        createCalled.setValue(true)
        return .mockWith()
      }
      $0.api.getConversationMessages = { _, _ in
        getMessagesCalled.setValue(true)
        return []
      }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    #expect(
      !createCalled.value, "Should not create a conversation just from viewing the page")
    #expect(!getMessagesCalled.value, "No conversation = no messages to fetch")
    #expect(model.conversation == nil)
    #expect(model.messages.isEmpty)
    #expect(!model.isLoading)
    #expect(model.presentedAlert == nil)
  }

  @Test
  func testSendMessageCreatesConversationWhenNoneExists() async {
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

    let createdConversation = makeConversation(id: "lazy-conv")
    let createCalled = LockIsolated(false)
    let sentMessage = makeMessage(
      id: "msg-1", conversationId: "lazy-conv", senderId: "user-1", text: "Hi there"
    )

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: nil, unreadCount: 0)
      }
      $0.api.createSupportConversation = { _ in
        createCalled.setValue(true)
        return CreateSupportConversationResponse(
          conversation: createdConversation, unreadCount: 0)
      }
      $0.api.sendConversationMessage = { _, conversationId, text in
        #expect(conversationId == "lazy-conv")
        #expect(text == "Hi there")
        return sentMessage
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()
    #expect(model.conversation == nil)

    model.newMessage = "Hi there"
    await model.sendMessage()

    #expect(createCalled.value)
    #expect(model.conversation?.id == "lazy-conv")
    #expect(model.messages.count == 1)
    #expect(model.messages.first?.message == "Hi there")
    #expect(model.newMessage.isEmpty)
  }

  @Test
  func testSendMessageRestoresMessageAndShowsAlertWhenCreateFails() async {
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

    let sendCalled = LockIsolated(false)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: nil, unreadCount: 0)
      }
      $0.api.createSupportConversation = { _ in
        throw APIError.validationError("create failed")
      }
      $0.api.sendConversationMessage = { _, _, _ in
        sendCalled.setValue(true)
        return Message(
          id: "x", conversationId: "x", senderId: "x",
          message: "x", createdAt: Date(), updatedAt: Date(), sender: nil
        )
      }
      $0.api.getConversationMessages = { _, _ in [] }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    model.newMessage = "Hello"
    await model.sendMessage()

    #expect(!sendCalled.value, "Should not call send when create fails")
    #expect(model.conversation == nil)
    #expect(model.newMessage == "Hello", "newMessage should be restored")
    #expect(model.presentedAlert == .errorSendingMessage)
    #expect(!model.isSending)
  }

  @Test
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
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
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

    #expect(!createCalled.value)
    #expect(model.conversation?.id == "existing-conv")
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
    #expect(!getConversationMessagesCalled.value)

    await model.handleScenePhaseChange(.inactive)
    #expect(!getConversationMessagesCalled.value)
  }

  @Test
  func testRefreshFinishingAfterSendKeepsSentMessage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let oldMessage = makeMessage(
      id: "old-msg", conversationId: "conv-1", senderId: "support-1", text: "Old")
    let sentMessage = makeMessage(
      id: "sent-msg", conversationId: "conv-1", senderId: "user-1", text: "Hi")
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let hasSent = LockIsolated(false)
    let fetchCount = LockIsolated(0)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        let isFirstFetch = fetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        let response = hasSent.value ? [oldMessage, sentMessage] : [oldMessage]
        guard isFirstFetch else { return response }
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return response
      }
      $0.api.sendConversationMessage = { _, _, _ in
        hasSent.setValue(true)
        return sentMessage
      }
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
    } operation: {
      SupportPageModel()
    }
    model.conversation = makeConversation(id: "conv-1")
    model.messages = [oldMessage]

    let refresh = Task { await model.refreshMessages() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    model.newMessage = "Hi"
    await model.sendMessage()
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await refresh.value

    expectNoDifference(model.messages.map(\.id), ["old-msg", "sent-msg"])
  }

  @Test
  func testSendFinishingAfterRefreshDoesNotDuplicateSentMessage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let oldMessage = makeMessage(
      id: "old-msg", conversationId: "conv-1", senderId: "support-1", text: "Old")
    let sentMessage = makeMessage(
      id: "sent-msg", conversationId: "conv-1", senderId: "user-1", text: "Hi")
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let (sendStarted, sendStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseSend, releaseSendContinuation) = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [oldMessage, sentMessage]
      }
      $0.api.sendConversationMessage = { _, _, _ in
        sendStartedContinuation.yield(())
        var releaseSendIterator = releaseSend.makeAsyncIterator()
        _ = await releaseSendIterator.next()
        return sentMessage
      }
      $0.api.markConversationRead = { _, _ in }
      $0.pushNotifications.clearSupportBadge = {}
    } operation: {
      SupportPageModel()
    }
    model.conversation = makeConversation(id: "conv-1")
    model.messages = [oldMessage]

    let refresh = Task { await model.refreshMessages() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    model.newMessage = "Hi"
    let send = Task { await model.sendMessage() }
    var sendStartedIterator = sendStarted.makeAsyncIterator()
    _ = await sendStartedIterator.next()
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await refresh.value
    releaseSendContinuation.yield(())
    releaseSendContinuation.finish()
    await send.value

    expectNoDifference(model.messages.map(\.id), ["old-msg", "sent-msg"])
  }

  @Test
  func testFailedSendRestoresFailedTextAboveTextTypedDuringSend() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let (sendStarted, sendStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseSend, releaseSendContinuation) = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.sendConversationMessage = { _, _, _ in
        sendStartedContinuation.yield(())
        var releaseSendIterator = releaseSend.makeAsyncIterator()
        _ = await releaseSendIterator.next()
        throw APIError.dataNotValid
      }
    } operation: {
      SupportPageModel()
    }
    model.conversation = makeConversation(id: "conv-1")
    model.newMessage = "First message"

    let send = Task { await model.sendMessage() }
    var sendStartedIterator = sendStarted.makeAsyncIterator()
    _ = await sendStartedIterator.next()
    model.newMessage = "Second message"
    releaseSendContinuation.yield(())
    releaseSendContinuation.finish()
    await send.value

    expectNoDifference(model.newMessage, "First message\nSecond message")
    expectNoDifference(model.presentedAlert, .errorSendingMessage)
  }

  @Test
  func testOnViewAppearedShowsToastWhenLoadFails() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let shownToasts = LockIsolated<[PlayolaToast]>([])

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in throw APIError.dataNotValid }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    expectNoDifference(model.presentedAlert, nil)
    expectNoDifference(shownToasts.value.map(\.message), ["The conversation couldn't load."])
  }

  @Test
  func testOnViewAppearedReportsNonNetworkLoadFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.getSupportConversation = { _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    expectNoDifference(reportCount.value, 1)
  }

  @Test
  func testOnViewAppearedTagsMessagesEndpointWhenMessagesLoadFails() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let conversation = makeConversation(id: "conv-1")
    let reportedTags = LockIsolated<[String: String]>([:])
    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        SupportConversationResponse(conversation: conversation, unreadCount: 0)
      }
      $0.api.getConversationMessages = { _, _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, tags in reportedTags.setValue(tags) }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    expectNoDifference(reportedTags.value["endpoint"], "getConversationMessages")
  }

  @Test
  func testOnViewAppearedWithExistingConversationShowsToastWhenLoadFails() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }
    model.conversation = makeConversation(id: "conv-1")

    await model.onViewAppeared()

    expectNoDifference(shownToasts.value.map(\.message), ["The conversation couldn't load."])
    expectNoDifference(reportCount.value, 1)
    expectNoDifference(model.isLoading, false)
  }

  @Test
  func testBackgroundRefreshReportsFailureWithoutToast() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let model = withDependencies {
      $0.api.getConversationMessages = { _, _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }
    model.conversation = makeConversation(id: "conv-1")

    await model.handleScenePhaseChange(.active)

    expectNoDifference(reportCount.value, 1)
    expectNoDifference(shownToasts.value.map(\.message), [])
  }

  @Test
  func testOnViewAppearedDoesNotReportNetworkLoadFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.getSupportConversation = { _ in throw URLError(.notConnectedToInternet) }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
    } operation: {
      SupportPageModel()
    }

    await model.onViewAppeared()

    expectNoDifference(reportCount.value, 0)
  }

  @Test
  func testOlderLoadFailureDoesNotShowToastAfterNewerLoadSucceedsDuringErrorReporting() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let (errorReportingStarted, errorReportingStartedContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let (releaseErrorReporting, releaseErrorReportingContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let loadCount = LockIsolated(0)
    let shownToasts = LockIsolated<[PlayolaToast]>([])

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        let isOlderLoad = loadCount.withValue {
          $0 += 1
          return $0 == 1
        }
        if isOlderLoad { throw APIError.dataNotValid }
        return SupportConversationResponse(conversation: nil, unreadCount: 0)
      }
      $0.errorReporting.reportError = { _, _ in
        errorReportingStartedContinuation.yield(())
        var releaseIterator = releaseErrorReporting.makeAsyncIterator()
        _ = await releaseIterator.next()
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }

    let olderLoad = Task { await model.onViewAppeared() }
    var errorReportingStartedIterator = errorReportingStarted.makeAsyncIterator()
    _ = await errorReportingStartedIterator.next()
    await model.onViewAppeared()
    releaseErrorReportingContinuation.yield(())
    releaseErrorReportingContinuation.finish()
    await olderLoad.value

    expectNoDifference(shownToasts.value.map(\.message), [])
  }

  @Test
  func testOnViewAppearedShowsNoErrorWhenLoadCancelled() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let (loadStarted, loadStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseLoad, releaseLoadContinuation) = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.getSupportConversation = { _ in
        loadStartedContinuation.yield(())
        var releaseLoadIterator = releaseLoad.makeAsyncIterator()
        _ = await releaseLoadIterator.next()
        throw CancellationError()
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }

    let load = Task { await model.onViewAppeared() }
    var loadStartedIterator = loadStarted.makeAsyncIterator()
    _ = await loadStartedIterator.next()
    load.cancel()
    releaseLoadContinuation.yield(())
    releaseLoadContinuation.finish()
    await load.value

    expectNoDifference(model.presentedAlert, nil)
    expectNoDifference(shownToasts.value.map(\.message), [])
  }

  @Test
  func testOnViewAppearedStopsLoadingWhenCancelledDuringErrorReporting() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let (errorReportingStarted, errorReportingStartedContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let (releaseErrorReporting, releaseErrorReportingContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let model = withDependencies {
      $0.api.getSupportConversation = { _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in
        errorReportingStartedContinuation.yield(())
        var iterator = releaseErrorReporting.makeAsyncIterator()
        _ = await iterator.next()
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SupportPageModel()
    }

    let load = Task { await model.onViewAppeared() }
    var errorReportingStartedIterator = errorReportingStarted.makeAsyncIterator()
    _ = await errorReportingStartedIterator.next()
    load.cancel()
    releaseErrorReportingContinuation.yield(())
    releaseErrorReportingContinuation.finish()
    await load.value

    expectNoDifference(model.isLoading, false)
    expectNoDifference(shownToasts.value.map(\.message), [])
  }

  @Test
  func testSendButtonAccessibilityLabel() {
    let model = SupportPageModel()

    expectNoDifference(model.sendButtonAccessibilityLabel, "Send message")
  }
}
