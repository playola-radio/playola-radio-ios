//
//  SignInPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Sharing
import SwiftUI

@MainActor
@Observable
class SignInPageModel: ViewModel {
  @ObservationIgnored @Shared(.appleSignInInfo) var appleSignInInfo: AppleSignInInfo?
  @ObservationIgnored @Shared(.auth) var auth: Auth
  var navigationCoordinator: NavigationCoordinator!
  var api: API

  init(api: API? = nil, navigationCoordinator: NavigationCoordinator = .shared) {
    self.api = api ?? API()
    self.navigationCoordinator = navigationCoordinator
  }

  // MARK: State
  var presentedAlert: PlayolaAlert?

  // MARK: Actions

  func signInWithAppleButtonTapped(request: ASAuthorizationAppleIDRequest) {
    request.requestedScopes = [.email, .fullName]
  }

  func signInWithAppleCompleted(result: Result<ASAuthorization, any Error>) {
    switch result {
    case let .success(authorization):
      guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityTokenData = appleIDCredential.identityToken,
            let identityToken = String(data: identityTokenData, encoding: .utf8),
            let authCodeData = appleIDCredential.authorizationCode,
            let authCode = String(data: authCodeData, encoding: .utf8)
      else {
        self.presentedAlert = PlayolaAlert.appleSignInError("Error decoding sign in info from Apple.")
        return
      }

      // Cache the email if this is the first time.
      if appleIDCredential.user != appleSignInInfo?.appleUserId,
         let email = appleIDCredential.email {
        $appleSignInInfo.withLock {
          $0 = AppleSignInInfo(
            appleUserId: appleIDCredential.user,
            email: email,
            displayName: appleIDCredential.fullName?.formatted()
          )
        }
      }

      // Use the email from this sign in or from cache.
      guard let email = appleIDCredential.email ?? appleSignInInfo?.email else {
        self.presentedAlert = PlayolaAlert.appleSignInError("Error trying to sign in -- no email ever.")
        return
      }

      Task { @MainActor in
        do {
          try await self.api.signInViaApple(identityToken: identityToken,
                                            email: email,
                                            authCode: authCode,
                                            displayName: appleIDCredential.fullName?.formatted())
          self.navigationCoordinator.activePath = .listen
        } catch {
          self.presentedAlert = PlayolaAlert.appleSignInError("Error signing in via Apple: \(error.localizedDescription)")
        }
      }

    case let .failure(error):
      self.presentedAlert = PlayolaAlert.appleSignInError(error.localizedDescription)
    }
  }

  func signInWithGoogleButtonTapped() {
    // Obtain a valid presenting view controller.
    guard let presentingVC = UIApplication.shared.keyWindowPresentedController else {
      self.presentedAlert = .googleSignInError("No key window available for presenting view controller.")
      return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] signInResult, error in
      guard let self = self else { return }

      if let error = error {
        self.presentedAlert = .googleSignInError(error.localizedDescription)
        return
      }

      guard let signInResult = signInResult else {
        self.presentedAlert = .googleSignInError("signInResult is nil.")
        return
      }

      print("Google sign in result: \(signInResult)")

      // Refresh tokens if needed.
      signInResult.user.refreshTokensIfNeeded { [weak self] _, error in
        guard let self = self else { return }

        if let error = error {
          self.presentedAlert = .googleSignInError("Error refreshing tokens: \(error.localizedDescription)")
          return
        }

        guard let serverAuthCode = signInResult.serverAuthCode else {
          self.presentedAlert = .googleSignInError(
            "Error signing into Google -- no serverAuthCode on signInResult.")
          return
        }

        Task { @MainActor in
          do {
            try await self.api.signInViaGoogle(code: serverAuthCode)
            self.navigationCoordinator.activePath = .listen
          } catch (let error) {
            self.presentedAlert = .googleSignInError(
              "Error signing into Playola with Google Token: \(error.localizedDescription)")
          }
        }
      }
    }
  }

  func logOutButtonTapped() {
    $auth.withLock { $0 = Auth() }
    Task { try await API().revokeAppleCredentials(appleUserId: "000014.59c02331e3a642fd8bebedd86d191ed3.1758") }
  }
}

extension PlayolaAlert {
  static func googleSignInError(_ message: String) -> PlayolaAlert {
    return PlayolaAlert(
      title: "Error Signing In With Google",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func appleSignInError(_ message: String) -> PlayolaAlert {
    return PlayolaAlert(
      title: "Error Signing In With Apple",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
