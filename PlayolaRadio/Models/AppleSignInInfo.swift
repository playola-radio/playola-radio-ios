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
  let firstName: String?
  let lastName: String?

  static func == (lhs: AppleSignInInfo, rhs: AppleSignInInfo) -> Bool {
    lhs.appleUserId == rhs.appleUserId && lhs.email == rhs.email
      && lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(appleUserId)
    hasher.combine(email)
    hasher.combine(firstName)
    hasher.combine(lastName)
  }
}