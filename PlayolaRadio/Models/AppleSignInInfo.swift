//
//  AppleSignInInfo.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//
import Foundation

struct AppleSignInInfo: Codable, Equatable {
  let appleUserId: String
  let email: String
  let displayName: String?

  static func == (lhs: AppleSignInInfo, rhs: AppleSignInInfo) -> Bool {
    lhs.appleUserId == rhs.appleUserId && lhs.email == rhs.email
      && lhs.displayName == rhs.displayName
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(appleUserId)
    hasher.combine(email)
    hasher.combine(displayName)
  }
}
