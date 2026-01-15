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
