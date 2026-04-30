import AuthenticationServices
import Dependencies
@preconcurrency import GoogleSignIn
import GoogleSignInSwift
import Sharing
//
//  SignInPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/25.
//
import SwiftUI

@MainActor
@Observable
class SignInPageModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.appRating) var appRating
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) var auth: Auth

  // MARK: - Initialization
  @MainActor
  override init() {
    super.init()
  }

  // MARK: - Properties
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored
  var keyWindowProvider: @MainActor () -> UIViewController? = {
    UIApplication.shared.keyWindowPresentedController
  }

  // MARK: - User Actions

  func signInWithAppleButtonTapped(request: ASAuthorizationAppleIDRequest) {
    request.requestedScopes = [.email, .fullName]
    Task { await analytics.track(.signInStarted(method: .apple)) }
  }

  func signInWithAppleCompleted(result: Result<ASAuthorization, any Error>) {
    switch result {
    case .success(let authorization):

      guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let identityTokenData = appleIDCredential.identityToken,
        let identityToken = String(data: identityTokenData, encoding: .utf8),
        let authCodeData = appleIDCredential.authorizationCode,
        let authCode = String(data: authCodeData, encoding: .utf8)
      else {
        print("Error decoding signin info from apple")
        presentedAlert = .signInError
        Task {
          await errorReporting.reportMessage(
            "Error decoding sign-in info from Apple",
            ["auth_method": "apple", "sign_in_step": "credential_decode"])
        }
        return
      }

      let email = appleIDCredential.email

      Task {
        do {
          let firstName = appleIDCredential.fullName?.givenName ?? ""
          let lastName = appleIDCredential.fullName?.familyName
          let token = try await api.signInViaApple(
            identityToken,
            email,  // Now optional - can be nil
            authCode,
            firstName,
            lastName)
          $auth.withLock { $0 = Auth(jwtToken: token) }
          appRating.recordInstallDateIfNeeded()
          await analytics.track(.signInCompleted(method: .apple, userId: appleIDCredential.user))
        } catch {
          print("Sign in failed: \(error)")
          presentedAlert = .signInError
          await analytics.track(.signInFailed(method: .apple, error: error.localizedDescription))
          await errorReporting.reportError(
            error,
            ["auth_method": "apple", "sign_in_step": "api_call"])
        }
      }
    case .failure(let error):
      handleAppleAuthorizationFailure(error)
    }
  }

  func signInWithGoogleButtonTapped() async {
    await analytics.track(.signInStarted(method: .google))
    guard let presentingVC = keyWindowProvider() else {
      print("Error presenting VC -- no key window")
      presentedAlert = .signInError
      await errorReporting.reportMessage(
        "Unable to present Google sign-in: no key window",
        ["auth_method": "google", "sign_in_step": "present_view_controller"])
      return
    }
    // Run the sign-in flow in a detached Task so the caller returns immediately
    // after firing .signInStarted, matching the prior callback-style contract.
    Task {
      do {
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        print(signInResult)

        _ = try await signInResult.user.refreshTokensIfNeeded()
        guard let serverAuthCode = signInResult.serverAuthCode else {
          print("Error signing into Google -- no serverAuthCode on signInResult.")
          presentedAlert = .signInError
          await errorReporting.reportMessage(
            "Google sign-in missing serverAuthCode",
            ["auth_method": "google", "sign_in_step": "server_auth_code"])
          return
        }
        let userId = signInResult.user.userID ?? "unknown"
        let token = try await api.signInViaGoogle(serverAuthCode)
        $auth.withLock { $0 = Auth(jwtToken: token) }
        appRating.recordInstallDateIfNeeded()
        await analytics.track(.signInCompleted(method: .google, userId: userId))
      } catch {
        print("Google sign in failed: \(error)")
        let nsError = error as NSError
        // Match the prior callback behavior: silently drop user-cancelled sign-ins
        // (GIDSignInError.canceled = -5) instead of tracking them as failures.
        if nsError.domain != kGIDSignInErrorDomain
          || nsError.code != GIDSignInError.canceled.rawValue
        {
          presentedAlert = .signInError
          await analytics.track(.signInFailed(method: .google, error: error.localizedDescription))
          await errorReporting.reportError(
            error,
            ["auth_method": "google", "sign_in_step": "google_sign_in_flow"])
        }
      }
    }
  }

  // MARK: - Private Helpers

  private func handleAppleAuthorizationFailure(_ error: any Error) {
    print(error)
    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
      return
    }
    presentedAlert = .signInError
    Task {
      await errorReporting.reportError(
        error,
        ["auth_method": "apple", "sign_in_step": "authorization_failure"])
    }
  }
}
