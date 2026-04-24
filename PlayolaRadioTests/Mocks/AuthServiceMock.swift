//
//  AuthServiceMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 2/27/25.
//
import ConcurrencyExtras

@testable import PlayolaRadio

class AuthServiceMock: AuthService, @unchecked Sendable {
  private let signOutCallCountStorage = LockIsolated(0)
  var signOutCallCount: Int { signOutCallCountStorage.value }

  override func signOut() {
    signOutCallCountStorage.withValue { $0 += 1 }
  }
}
