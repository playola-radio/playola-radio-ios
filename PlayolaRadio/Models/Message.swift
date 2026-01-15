//
//  Message.swift
//  PlayolaRadio
//

import Foundation

struct Message: Codable, Identifiable, Equatable {
  let id: String
  let conversationId: String
  let senderId: String
  let message: String
  let createdAt: Date
  let updatedAt: Date
  let sender: MessageSender?
}

struct MessageSender: Codable, Equatable {
  let id: String
  let firstName: String
  let lastName: String?
  let email: String
  let profileImageUrl: String?

  var fullName: String {
    [firstName, lastName].compactMap { $0 }.joined(separator: " ")
  }
}
