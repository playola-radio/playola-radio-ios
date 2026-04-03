//
//  Conversation.swift
//  PlayolaRadio
//

import Foundation

struct Conversation: Codable, Identifiable, Equatable {
  let id: String
  let type: String
  let contextType: String?
  let contextId: String?
  let status: String
  let createdAt: Date
  let updatedAt: Date
  let participants: [ConversationParticipant]?

  init(
    id: String,
    type: String,
    contextType: String?,
    contextId: String?,
    status: String,
    createdAt: Date,
    updatedAt: Date,
    participants: [ConversationParticipant]?
  ) {
    self.id = id
    self.type = type
    self.contextType = contextType
    self.contextId = contextId
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.participants = participants
  }

  var isOpen: Bool {
    status == "open"
  }

  var ownerParticipant: ConversationParticipant? {
    participants?.first { $0.role == "owner" }
  }

  var supportParticipant: ConversationParticipant? {
    participants?.first { $0.role == "support" }
  }
}

struct ConversationParticipant: Codable, Identifiable, Equatable {
  let id: String
  let conversationId: String
  let userId: String
  let role: String
  let lastReadAt: Date?
  let user: ParticipantUser?
}

struct ParticipantUser: Codable, Equatable {
  let id: String
  let firstName: String
  let lastName: String?
  let email: String
  let profileImageUrl: String?

  var fullName: String {
    [firstName, lastName].compactMap { $0 }.joined(separator: " ")
  }
}

struct SupportConversationResponse: Codable, Equatable {
  let conversation: Conversation?
  let unreadCount: Int
}

struct CreateSupportConversationResponse: Codable, Equatable {
  let conversation: Conversation
  let unreadCount: Int
}

struct AdminConversationResponse: Codable, Identifiable, Equatable {
  let conversation: Conversation
  let unreadCountFromOwner: Int

  var id: String { conversation.id }
}

// MARK: - Mock Helpers

extension Conversation {
  static func mockWith(
    id: String = "conv-1",
    type: String = "support",
    contextType: String? = nil,
    contextId: String? = nil,
    status: String = "open",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    participants: [ConversationParticipant]? = nil
  ) -> Conversation {
    Conversation(
      id: id,
      type: type,
      contextType: contextType,
      contextId: contextId,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      participants: participants
    )
  }
}

extension SupportConversationResponse {
  static func mockWith(
    conversation: Conversation? = .mockWith(),
    unreadCount: Int = 0
  ) -> SupportConversationResponse {
    SupportConversationResponse(
      conversation: conversation,
      unreadCount: unreadCount
    )
  }
}

extension CreateSupportConversationResponse {
  static func mockWith(
    conversation: Conversation = .mockWith(),
    unreadCount: Int = 0
  ) -> CreateSupportConversationResponse {
    CreateSupportConversationResponse(
      conversation: conversation,
      unreadCount: unreadCount
    )
  }
}
