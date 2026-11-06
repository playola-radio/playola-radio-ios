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
  func testRefreshRefetchesWhenConversationReadDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let isRead = LockIsolated(false)
    let fetchCount = LockIsolated(0)
    let unreadConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 1
    )
    let readConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 0
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        fetchCount.withValue { $0 += 1 }
        let response = isRead.value ? readConversation : unreadConversation
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [response]
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in isRead.setValue(true) }
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

    expectNoDifference(model.conversations, [readConversation])
    expectNoDifference(fetchCount.value, 2)
  }

  @Test
  func testRefreshKeepsMessageSentAfterReadUnread() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let isRead = LockIsolated(false)
    let unreadConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 1
    )
    let conversationWithMessageSentAfterRead = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 200), unreadCountFromOwner: 1
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        let response = isRead.value ? conversationWithMessageSentAfterRead : unreadConversation
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [response]
      }
      $0.api.getConversationMessages = { _, _ in [] }
      $0.api.markConversationRead = { _, _ in isRead.setValue(true) }
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

    expectNoDifference(model.conversations, [conversationWithMessageSentAfterRead])
  }

  @Test
  func testOlderRefreshDoesNotReplaceNewerRefresh() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderFetch, releaseOlderFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerFetch, releaseNewerFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let fetchCount = LockIsolated(0)
    let olderConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 100), unreadCountFromOwner: 0
    )
    let newerConversation = makeAdminConversation(
      id: "conv-1", updatedAt: Date(timeIntervalSince1970: 200), unreadCountFromOwner: 1
    )

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        let isOlderFetch = fetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        fetchStartedContinuation.yield(())
        var releaseIterator =
          (isOlderFetch ? releaseOlderFetch : releaseNewerFetch).makeAsyncIterator()
        _ = await releaseIterator.next()
        return [isOlderFetch ? olderConversation : newerConversation]
      }
    } operation: {
      ConversationListPageModel()
    }

    let olderRefresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    let newerRefresh = Task { await model.refresh() }
    _ = await fetchStartedIterator.next()
    releaseNewerFetchContinuation.yield(())
    releaseNewerFetchContinuation.finish()
    await newerRefresh.value
    releaseOlderFetchContinuation.yield(())
    releaseOlderFetchContinuation.finish()
    await olderRefresh.value

    expectNoDifference(model.conversations, [newerConversation])
    expectNoDifference(model.isLoading, false)
  }

  @Test
  func testOlderRefreshFinishingFirstKeepsLoadingUntilNewerRefreshFinishes() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderFetch, releaseOlderFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerFetch, releaseNewerFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let fetchCount = LockIsolated(0)

    let model = withDependencies {
      $0.api.getConversations = { _, _ in
        let isOlderFetch = fetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        fetchStartedContinuation.yield(())
        var releaseIterator =
          (isOlderFetch ? releaseOlderFetch : releaseNewerFetch).makeAsyncIterator()
        _ = await releaseIterator.next()
        return []
      }
    } operation: {
      ConversationListPageModel()
    }

    let olderRefresh = Task { await model.refresh() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    let newerRefresh = Task { await model.refresh() }
    _ = await fetchStartedIterator.next()
    releaseOlderFetchContinuation.yield(())
    releaseOlderFetchContinuation.finish()
    await olderRefresh.value

    expectNoDifference(model.isLoading, true)

    releaseNewerFetchContinuation.yield(())
    releaseNewerFetchContinuation.finish()
    await newerRefresh.value

    expectNoDifference(model.isLoading, false)
  }
}
