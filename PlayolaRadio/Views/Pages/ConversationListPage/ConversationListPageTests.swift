//
//  ConversationListPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

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
}
