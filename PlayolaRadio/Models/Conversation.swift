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
  let unreadCount: Int?

  init(
    id: String,
    type: String,
    contextType: String?,
    contextId: String?,
    status: String,
    createdAt: Date,
    updatedAt: Date,
    participants: [ConversationParticipant]?,
    unreadCount: Int? = nil
  ) {
    self.id = id
    self.type = type
    self.contextType = contextType
    self.contextId = contextId
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.participants = participants
    self.unreadCount = unreadCount
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
