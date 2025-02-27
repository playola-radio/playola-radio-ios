//
//  AuthServiceMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 2/27/25.
//
@testable import PlayolaRadio

class AuthServiceMock: AuthService {
  var signOutCallCount = 0

  override func signOut() {
    signOutCallCount += 1
  }
}
