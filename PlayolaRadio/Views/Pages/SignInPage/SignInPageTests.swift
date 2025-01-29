//
//  SignInPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//

import AuthenticationServices
@testable import PlayolaRadio
import Testing

@MainActor
struct SignInPageTests {
    // TODO: Add these tests
    @Test("Correctly adds scope to an apple sign in request")
    func testCorrectlyAddsScopeToTheAppleSignInRequest() {
        let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
        let model = SignInPageModel()
        model.signInWithAppleButtonTapped(request: request)
        #expect(request.requestedScopes == [.email, .fullName])
    }

    // TODO: Create these tests:
    @Suite("signInWithAppleCompleted()")
    struct signInWithAppleCompleted {
        // @Test("Can handle decoding error on appleIDCredential")
        // @Test("Stores appleSignInInfo if the email was received")
        // @Test("Notifies the user if there was no email cached and none provided")
        // @Test("Provides the results to the API")
    }

    // @Suite("SignInWithGoogle")
    // @Test("LogOutButtonTapped()")
}
