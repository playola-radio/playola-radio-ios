//
//  AuthServiceMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 2/27/25.
//
import PlayolaCore

@testable import PlayolaRadio

class AuthServiceMock: AuthService {
  var signOutCallCount = 0

  override func signOut() {
    signOutCallCount += 1
  }
}
