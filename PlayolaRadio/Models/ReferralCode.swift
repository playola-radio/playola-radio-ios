//
//  ReferralCode.swift
//  PlayolaRadio
//

import Foundation

struct ReferralCode: Codable, Equatable, Identifiable {
  let id: String
  let code: String
  let createdByUserId: String
  let invitationCodeId: String
  let maxUses: Int?
  let description: String?
  let expiresAt: Date?
  let isActive: Bool
  let createdAt: Date
  let updatedAt: Date
}
