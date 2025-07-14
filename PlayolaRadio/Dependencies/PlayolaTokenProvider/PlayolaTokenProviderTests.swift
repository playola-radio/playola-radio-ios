//
//  PlayolaTokenProviderTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 2/13/25.
//

// swiftlint:disable force_try

import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct PlayolaTokenProviderTests {

  // Helper function to create valid JWT tokens for testing
  static func createTestJWT(
    id: String = "test-user-123",
    displayName: String = "Test User",
    email: String = "test@example.com",
    profileImageUrl: String? = nil,
    role: String = "user"
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "displayName": displayName,
      "email": email,
      "role": role,
    ]
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

  @Suite("getCurrentToken")
  struct GetCurrentToken {
    @Test("Returns nil when user not logged in")
    func testReturnsNilWhenUserNotLoggedIn() async {
      @Shared(.auth) var auth = Auth()
      let tokenProvider = PlayolaTokenProvider()

      let token = await tokenProvider.getCurrentToken()

      #expect(token == nil)
    }

    @Test("Returns JWT when user is logged in")
    func testReturnsJWTWhenUserLoggedIn() async {
      let expectedJWT = await createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
      let tokenProvider = PlayolaTokenProvider()

      let token = await tokenProvider.getCurrentToken()

      #expect(token == expectedJWT)
    }

    @Test("Returns nil immediately after user signs out")
    func testReturnsNilAfterUserSignsOut() async {
      let initialJWT = await createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: initialJWT)
      let tokenProvider = PlayolaTokenProvider()

      // Sign out user
      $auth.withLock { $0 = Auth() }

      let token = await tokenProvider.getCurrentToken()
      #expect(token == nil)
    }
  }

  @Suite("refreshToken")
  struct RefreshToken {
    @Test("Returns nil when user not logged in")
    func testReturnsNilWhenUserNotLoggedIn() async {
      @Shared(.auth) var auth = Auth()
      let tokenProvider = PlayolaTokenProvider()

      let token = await tokenProvider.refreshToken()

      #expect(token == nil)
    }

    @Test("Returns current JWT when user is logged in")
    func testReturnsCurrentJWTWhenUserLoggedIn() async {
      let expectedJWT = await createTestJWT()
      @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
      let tokenProvider = PlayolaTokenProvider()

      let token = await tokenProvider.refreshToken()

      #expect(token == expectedJWT)
    }
  }

  @Suite("Reactive Authentication State Changes")
  struct ReactiveAuthChanges {
    @Test("Immediately reflects auth state changes")
    func testImmediatelyReflectsAuthStateChanges() async {
      @Shared(.auth) var auth = Auth()
      let tokenProvider = PlayolaTokenProvider()

      // Initially no token
      #expect(await tokenProvider.getCurrentToken() == nil)

      // User logs in
      let jwt = await createTestJWT()
      $auth.withLock { $0 = Auth(jwtToken: jwt) }

      // Token provider immediately reflects the change
      #expect(await tokenProvider.getCurrentToken() == jwt)

      // User logs out
      $auth.withLock { $0 = Auth() }

      // Token provider immediately reflects the logout
      #expect(await tokenProvider.getCurrentToken() == nil)
    }

    @Test("Multiple auth state changes are tracked correctly")
    func testMultipleAuthStateChangesTracked() async {
      @Shared(.auth) var auth = Auth()
      let tokenProvider = PlayolaTokenProvider()

      let tokens = [
        await createTestJWT(id: "user1", displayName: "User One"),
        await createTestJWT(id: "user2", displayName: "User Two"),
        await createTestJWT(id: "user3", displayName: "User Three"),
      ]

      for expectedToken in tokens {
        $auth.withLock { $0 = Auth(jwtToken: expectedToken) }
        let actualToken = await tokenProvider.getCurrentToken()
        #expect(actualToken == expectedToken)
      }

      // Final logout
      $auth.withLock { $0 = Auth() }
      #expect(await tokenProvider.getCurrentToken() == nil)
    }
  }
}

// swiftlint:enable force_try
