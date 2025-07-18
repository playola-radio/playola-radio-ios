//
//  SignInPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//

import AuthenticationServices
import XCTest

@testable import PlayolaRadio

@MainActor
final class SignInPageTests: XCTestCase {
  // TODO: Add these tests
  func testSignInWithApple_CorrectlyAddsScopeToTheAppleSignInRequest() {
    let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
    let model = SignInPageModel()
    model.signInWithAppleButtonTapped(request: request)
    XCTAssertEqual(request.requestedScopes, [.email, .fullName])
  }

  // TODO: Create these tests:
  // MARK: - signInWithAppleCompleted() Tests

  // func testSignInWithAppleCompleted_CanHandleDecodingErrorOnAppleIDCredential() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_StoresAppleSignInInfoIfEmailWasReceived() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_NotifiesUserIfNoEmailCachedAndNoneProvided() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_ProvidesResultsToAPI() {
  //   // TODO: Implement test
  // }

  // MARK: - SignInWithGoogle Tests
  // TODO: Implement Google sign in tests

  // MARK: - LogOutButtonTapped Tests
  // func testLogOutButtonTapped() {
  //   // TODO: Implement test
  // }
}
