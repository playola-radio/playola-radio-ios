//
//  PlayolaTokenProviderTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 2/13/25.
//

// swiftlint:disable force_try

import Foundation
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class PlayolaTokenProviderTests: XCTestCase {

  // Helper function to create valid JWT tokens for testing
  func createTestJWT(
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

  // MARK: - getCurrentToken Tests

  func testGetCurrentToken_ReturnsNilWhenUserNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.getCurrentToken()

    XCTAssertNil(token)
  }

  func testGetCurrentToken_ReturnsJWTWhenUserLoggedIn() async {
    let expectedJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.getCurrentToken()

    XCTAssertEqual(token, expectedJWT)
  }

  func testGetCurrentToken_ReturnsNilAfterUserSignsOut() async {
    let initialJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: initialJWT)
    let tokenProvider = PlayolaTokenProvider()

    // Sign out user
    $auth.withLock { $0 = Auth() }

    let token = await tokenProvider.getCurrentToken()
    XCTAssertNil(token)
  }

  // MARK: - refreshToken Tests

  func testRefreshToken_ReturnsNilWhenUserNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.refreshToken()

    XCTAssertNil(token)
  }

  func testRefreshToken_ReturnsCurrentJWTWhenUserLoggedIn() async {
    let expectedJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
    let tokenProvider = PlayolaTokenProvider()

    let token = await tokenProvider.refreshToken()

    XCTAssertEqual(token, expectedJWT)
  }

  // MARK: - Reactive Authentication State Changes Tests

  func testReactiveAuth_ImmediatelyReflectsAuthStateChanges() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    // Initially no token
    let initialToken = await tokenProvider.getCurrentToken()
    XCTAssertNil(initialToken)

    // User logs in
    let jwt = createTestJWT()
    $auth.withLock { $0 = Auth(jwtToken: jwt) }

    // Token provider immediately reflects the change
    let newToken = await tokenProvider.getCurrentToken()
    XCTAssertEqual(newToken, jwt)

    // User logs out
    $auth.withLock { $0 = Auth() }

    // Token provider immediately reflects the logout
    let loggedOutToken = await tokenProvider.getCurrentToken()
    XCTAssertNil(loggedOutToken)
  }

  func testReactiveAuth_MultipleAuthStateChangesTracked() async {
    @Shared(.auth) var auth = Auth()
    let tokenProvider = PlayolaTokenProvider()

    let tokens = [
      createTestJWT(id: "user1", displayName: "User One"),
      createTestJWT(id: "user2", displayName: "User Two"),
      createTestJWT(id: "user3", displayName: "User Three"),
    ]

    for expectedToken in tokens {
      $auth.withLock { $0 = Auth(jwtToken: expectedToken) }
      let actualToken = await tokenProvider.getCurrentToken()
      XCTAssertEqual(actualToken, expectedToken)
    }

    // Final logout
    $auth.withLock { $0 = Auth() }
    let finalToken = await tokenProvider.getCurrentToken()
    XCTAssertNil(finalToken)
  }
}

// swiftlint:enable force_try
