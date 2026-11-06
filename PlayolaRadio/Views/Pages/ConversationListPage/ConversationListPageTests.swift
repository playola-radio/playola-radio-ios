//
//  ConversationListPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ConversationListPageTests {
  private func makeConversation(
    id: String,
    updatedAt: Date = Date(),
    ownerFirstName: String = "Test",
    ownerLastName: String = "User"
  ) -> Conversation {
    Conversation(
      id: id,
      type: "support",
      contextType: nil,
      contextId: nil,
      status: "open",
      createdAt: Date(),
      updatedAt: updatedAt,
      participants: [
        ConversationParticipant(
          id: "part-\(id)",
          conversationId: id,
          userId: "user-\(id)",
          role: "owner",
          lastReadAt: nil,
          user: ParticipantUser(
            id: "user-\(id)",
            firstName: ownerFirstName,
            lastName: ownerLastName,
            email: "\(ownerFirstName.lowercased())@example.com",
            profileImageUrl: nil
          )
        )
      ]
    )
  }

  private func makeAdminConversation(
    id: String,
    updatedAt: Date,
    unreadCountFromOwner: Int
  ) -> AdminConversationResponse {
    AdminConversationResponse(
      conversation: makeConversation(id: id, updatedAt: updatedAt),
      unreadCountFromOwner: unreadCountFromOwner
    )
  }

  private func makeMessage(id: String, conversationId: String, updatedAt: Date) -> Message {
    Message(
      id: id,
      conversationId: conversationId,
      senderId: "owner-1",
      message: "New message",
      createdAt: updatedAt,
      updatedAt: updatedAt,
      sender: nil
    )
  }

  @Test
  func testOnViewAppearedLoadsConversations() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "admin-1",
        firstName: "Admin",
        lastName: "User",
        email: "admin@example.com",
        profileImageUrl: nil,
        role: "admin"
      ),
      jwt: "test-jwt"
    )

    let testConversations = [
      AdminConversationResponse(
        conversation: makeConversation(id: "conv-1", ownerFirstName: "John"),
        unreadCountFromOwner: 3
      ),
      AdminConversationResponse(
        conversation: makeConversation(id: "conv-2", ownerFirstName: "Jane"),
        unreadCountFromOwner: 0
      ),
    ]

    let model = withDependencies {
      $0.api.getConversations = { _, _ in testConversations }
    } operation: {
      ConversationListPageModel()
    }

    #expect(model.isLoading == true)
    #expect(model.conversations.isEmpty)

    await model.onViewAppeared()

    #expect(model.isLoading == false)
    #expect(model.conversations.count == 2)
  }

  @Test
  func testShowsLoadingIndicatorWhileLoadingWithNoConversations() {
    let model = ConversationListPageModel()

    model.isLoading = true

    #expect(model.showsLoadingIndicator)
  }

  @Test
  func testHidesLoadingIndicatorAfterLoadingWithNoConversations() {
    let model = ConversationListPageModel()

    model.isLoading = false

    #expect(!model.showsLoadingIndicator)
  }

  @Test
  func testHidesLoadingIndicatorWhileRefreshingExistingConversations() {
    let model = ConversationListPageModel()
    model.conversations = [
      AdminConversationResponse(
        conversation: makeConversation(id: "conv-1"), unreadCountFromOwner: 0)
    ]

    model.isLoading = true

    #expect(!model.showsLoadingIndicator)
  }

  @Test
  func testRefreshDoesNotShowAlertWhenCancelled() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let (requestStarted, requestStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseRequest, _) = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        requestStartedContinuation.yield(())
        var releaseIterator = releaseRequest.makeAsyncIterator()
        _ = await releaseIterator.next()
        throw URLError(.cancelled)
      }
    } operation: {
      ConversationListPageModel()
    }

    let refresh = Task { await model.refresh() }
    var requestStartedIterator = requestStarted.makeAsyncIterator()
    _ = await requestStartedIterator.next()
    refresh.cancel()
    await refresh.value

    #expect(model.presentedAlert == nil)
    #expect(!model.isLoading)
  }

  @Test
  func testRefreshShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = withDependencies {
      $0.api.getConversations = { _, _ in throw URLError(.notConnectedToInternet) }
    } operation: {
      ConversationListPageModel()
    }

    await model.refresh()

    #expect(model.presentedAlert != nil)
  }

  @Test
  func testSortedConversationsPlacesUnreadFirst() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "admin-1",
        firstName: "Admin",
        lastName: "User",
        email: "admin@example.com",
        profileImageUrl: nil,
        role: "admin"
      ),
      jwt: "test-jwt"
    )

    let olderDate = Date().addingTimeInterval(-3600)
    let newerDate = Date()

    let testConversations = [
      AdminConversationResponse(
        conversation: makeConversation(
          id: "conv-1", updatedAt: newerDate, ownerFirstName: "NoUnread"),
        unreadCountFromOwner: 0
      ),
      AdminConversationResponse(
        conversation: makeConversation(
          id: "conv-2", updatedAt: olderDate, ownerFirstName: "HasUnread"),
        unreadCountFromOwner: 5
      ),
    ]

    let model = withDependencies {
      $0.api.getConversations = { _, _ in testConversations }
    } operation: {
      ConversationListPageModel()
    }

    await model.onViewAppeared()

    let sorted = model.sortedConversations

    #expect(sorted.count == 2)
    #expect(sorted[0].conversation.ownerParticipant?.user?.firstName == "HasUnread")
    #expect(sorted[1].conversation.ownerParticipant?.user?.firstName == "NoUnread")
  }

  @Test
  func testSortedConversationsSortsByDateWhenSameUnreadStatus() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "admin-1",
        firstName: "Admin",
        lastName: "User",
        email: "admin@example.com",
        profileImageUrl: nil,
        role: "admin"
      ),
      jwt: "test-jwt"
    )

    let olderDate = Date().addingTimeInterval(-3600)
    let newerDate = Date()

    let testConversations = [
      AdminConversationResponse(
        conversation: makeConversation(id: "conv-1", updatedAt: olderDate, ownerFirstName: "Older"),
        unreadCountFromOwner: 0
      ),
      AdminConversationResponse(
        conversation: makeConversation(id: "conv-2", updatedAt: newerDate, ownerFirstName: "Newer"),
        unreadCountFromOwner: 0
      ),
    ]

    let model = withDependencies {
      $0.api.getConversations = { _, _ in testConversations }
    } operation: {
      ConversationListPageModel()
    }

    await model.onViewAppeared()

    let sorted = model.sortedConversations

    #expect(sorted[0].conversation.ownerParticipant?.user?.firstName == "Newer")
    #expect(sorted[1].conversation.ownerParticipant?.user?.firstName == "Older")
  }

  @Test
  func testOnConversationTappedClearsUnreadCount() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "admin-1",
        firstName: "Admin",
        lastName: "User",
        email: "admin@example.com",
        profileImageUrl: nil,
        role: "admin"
      ),
      jwt: "test-jwt"
    )
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let markAsReadCalled = LockIsolated(false)
    let markedConversationId = LockIsolated<String?>(nil)

    let testConversation = AdminConversationResponse(
      conversation: makeConversation(id: "conv-1", ownerFirstName: "John"),
      unreadCountFromOwner: 5
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in [testConversation] }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, conversationId in
        markAsReadCalled.setValue(true)
        markedConversationId.setValue(conversationId)
      }
    } operation: {
      ConversationListPageModel()
    }

    await model.onViewAppeared()

    #expect(model.conversations.first?.unreadCountFromOwner == 5)

    await model.onConversationTapped(testConversation)

    #expect(markAsReadCalled.value == true)
    #expect(markedConversationId.value == "conv-1")
    #expect(model.conversations.first?.unreadCountFromOwner == 0)
  }

  @Test
  func testRefreshPreservesConversationReadDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let unreadConversation = AdminConversationResponse(
      conversation: makeConversation(id: "conv-1"), unreadCountFromOwner: 1)

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [unreadConversation]
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      ConversationListPageModel()
    }
    model.conversations = [unreadConversation]

    let refresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    await model.onConversationTapped(unreadConversation)
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await refresh.value

    #expect(model.conversations.first?.unreadCountFromOwner == 0)
  }

  @Test
  func testRefreshKeepsNewerUnreadMessagesAfterConversationReadDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let unreadConversation = AdminConversationResponse(
      conversation: makeConversation(id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100)),
      unreadCountFromOwner: 1
    )
    let conversationWithNewerMessage = AdminConversationResponse(
      conversation: makeConversation(id: "conv-1", updatedAt: Date(timeIntervalSince1970: 200)),
      unreadCountFromOwner: 1
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [conversationWithNewerMessage]
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      ConversationListPageModel()
    }
    model.conversations = [unreadConversation]

    let refresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    await model.onConversationTapped(unreadConversation)
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await refresh.value

    expectNoDifference(model.conversations, [conversationWithNewerMessage])
  }

  @Test
  func testRefreshKeepsFetchedMessagesReadDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let oldConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 1
    )
    let refreshedConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 200), unreadCountFromOwner: 1
    )
    let fetchedMessage = makeMessage(
      id: "message-1", conversationId: "conv-1", updatedAt: Date(timeIntervalSince1970: 200)
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [refreshedConversation]
      }
      $0.api.getConversationMessages = { _, _ in [fetchedMessage] }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      ConversationListPageModel()
    }
    model.conversations = [oldConversation]

    let refresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    await model.onConversationTapped(oldConversation)
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await refresh.value

    expectNoDifference(
      model.conversations,
      [
        AdminConversationResponse(
          conversation: refreshedConversation.conversation,
          unreadCountFromOwner: 0
        )
      ]
    )
  }

  @Test
  func testOlderRefreshDoesNotReplaceNewerRefresh() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Int.self)
    let (releaseOlderFetch, releaseOlderFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerFetch, releaseNewerFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let fetchCount = LockIsolated(0)
    let oldConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 1
    )
    let newerConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 200), unreadCountFromOwner: 1
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        let requestNumber = fetchCount.withValue {
          $0 += 1
          return $0
        }
        fetchStartedContinuation.yield(requestNumber)
        if requestNumber == 1 {
          var releaseIterator = releaseOlderFetch.makeAsyncIterator()
          _ = await releaseIterator.next()
          return [oldConversation]
        }
        var releaseIterator = releaseNewerFetch.makeAsyncIterator()
        _ = await releaseIterator.next()
        return [newerConversation]
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in }
    } operation: {
      ConversationListPageModel()
    }
    model.conversations = [oldConversation]

    let olderRefresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    let newerRefresh = Task { await model.refresh() }
    _ = await fetchStartedIterator.next()
    await model.onConversationTapped(oldConversation)
    releaseNewerFetchContinuation.yield(())
    releaseNewerFetchContinuation.finish()
    await newerRefresh.value
    releaseOlderFetchContinuation.yield(())
    releaseOlderFetchContinuation.finish()
    await olderRefresh.value

    expectNoDifference(model.conversations, [newerConversation])
    expectNoDifference(model.isLoading, false)
  }
}
