//
//  PlayolaTokenProviderTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 2/13/25.
//

// swiftlint:disable force_try

import ConcurrencyExtras
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct PlayolaTokenProviderTests {

  // Helper function to create valid JWT tokens for testing
  private func createTestJWT(
    id: String = "test-user-123",
    firstName: String = "Test",
    lastName: String? = "User",
    email: String = "test@example.com",
    profileImageUrl: String? = nil,
    role: String = "user"
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "firstName": firstName,
      "email": email,
      "role": role,
    ]
    if let lastName = lastName {
      payload["lastName"] = lastName
    }
    if let profileImageUrl = profileImageUrl {
      payload["profileImageUrl"] = profileImageUrl
    }

    let headerData = try! JSONSerialization.data(withJSONObject: header)
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)

    let headerString = headerData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    let payloadString = payloadData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return "\(headerString).\(payloadString).fake_signature"
  }

  // MARK: - getCurrentToken Tests

  @Test
  func testGetCurrentTokenReturnsNilWhenUserNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.getCurrentToken()

    #expect(token == nil)
  }

  @Test
  func testGetCurrentTokenReturnsJWTWhenUserLoggedIn() async {
    let expectedJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.getCurrentToken()

    #expect(token == expectedJWT)
  }

  @Test
  func testGetCurrentTokenReturnsNilAfterUserSignsOut() async {
    let initialJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: initialJWT)
    let tokenProvider = PlayolaTokenProvider()

    // Sign out user
    $auth.withLock { $0 = Auth() }

    let token = await tokenProvider.getCurrentToken()
    #expect(token == nil)
  }

  // MARK: - refreshToken Tests

  @Test
  func testRefreshTokenReturnsNilWhenUserNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.refreshToken()

    #expect(token == nil)
  }

  @Test
  func testRefreshTokenReturnsCurrentJWTWhenUserLoggedIn() async {
    let expectedJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.refreshToken()

    #expect(token == expectedJWT)
  }

  // MARK: - Reactive Authentication State Changes Tests

  @Test
  func testReactiveAuthImmediatelyReflectsAuthStateChanges() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    // Initially no token
    let initialToken = await tokenProvider.getCurrentToken()
    #expect(initialToken == nil)

    // User logs in
    let jwt = createTestJWT()
    $auth.withLock { $0 = Auth(jwtToken: jwt) }

    // Token provider immediately reflects the change
    let newToken = await tokenProvider.getCurrentToken()
    #expect(newToken == jwt)

    // User logs out
    $auth.withLock { $0 = Auth() }

    // Token provider immediately reflects the logout
    let loggedOutToken = await tokenProvider.getCurrentToken()
    #expect(loggedOutToken == nil)
  }

  @Test
  func testReactiveAuthMultipleAuthStateChangesTracked() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let tokens = [
      createTestJWT(id: "user1", firstName: "User", lastName: "One"),
      createTestJWT(id: "user2", firstName: "User", lastName: "Two"),
      createTestJWT(id: "user3", firstName: "User", lastName: "Three"),
    ]

    for expectedToken in tokens {
      $auth.withLock { $0 = Auth(jwtToken: expectedToken) }
      let actualToken = await tokenProvider.getCurrentToken()
      #expect(actualToken == expectedToken)
    }

    // Final logout
    $auth.withLock { $0 = Auth() }
    let finalToken = await tokenProvider.getCurrentToken()
    #expect(finalToken == nil)
  }
}

// swiftlint:enable force_try
