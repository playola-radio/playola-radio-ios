import AuthenticationServices
import Dependencies
import GoogleSignIn
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
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.appRating) var appRating
  @ObservationIgnored @Shared(.auth) var auth: Auth

  @MainActor
  override init() {
    super.init()
  }

  // MARK: Actions

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
          await analytics.track(.signInFailed(method: .apple, error: error.localizedDescription))
        }
      }
    case .failure(let error):
      print(error)
    }
  }

  func signInWithGoogleButtonTapped() async {
    await analytics.track(.signInStarted(method: .google))
    guard let presentingVC = UIApplication.shared.keyWindowPresentedController else {
      print("Error presenting VC -- no key window")
      return
    }
    GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { signInResult, error in
      guard let signInResult else {
        return
      }
      print(signInResult)

      signInResult.user.refreshTokensIfNeeded { _, error in
        guard error == nil else { return }
        guard let serverAuthCode = signInResult.serverAuthCode else {
          print("Error signing into Google -- no serverAuthCode on signInResult.")
          return
        }
        let userId = signInResult.user.userID ?? "unknown"
        Task { @MainActor in
          do {
            let token = try await self.api.signInViaGoogle(serverAuthCode)
            self.$auth.withLock { $0 = Auth(jwtToken: token) }
            self.appRating.recordInstallDateIfNeeded()
            await self.analytics.track(
              .signInCompleted(method: .google, userId: userId))
          } catch {
            print("Google sign in failed: \(error)")
            await self.analytics.track(
              .signInFailed(method: .google, error: error.localizedDescription))
          }
        }
      }
    }
  }
}
