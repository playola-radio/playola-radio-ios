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
  @ObservationIgnored @Shared(.appleSignInInfo) var appleSignInInfo: AppleSignInInfo?
  @ObservationIgnored @Shared(.auth) var auth: Auth
  var navigationCoordinator: NavigationCoordinator
  var config: Config

  private var _invitationCodesPageModel = InvitationCodePageModel()
  var invitationCodesPageModel: InvitationCodePageModel? {
    return self.config.shouldShowInvitationCodePage ? _invitationCodesPageModel : nil
  }

  init(navigationCoordinator: NavigationCoordinator = .shared, config: Config = .shared) {
    self.navigationCoordinator = navigationCoordinator
    self.config = config
  }

  // MARK: Actions

  func signInWithAppleButtonTapped(request: ASAuthorizationAppleIDRequest) async {
    request.requestedScopes = [.email, .fullName]
    await analytics.track(.signInStarted(method: .apple))
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
        print("Error decoding signin info from apple")
        return
      }
      if appleIDCredential.user != appleSignInInfo?.appleUserId,
        let email = appleIDCredential.email
      {
        $appleSignInInfo.withLock {
          $0 = AppleSignInInfo(
            appleUserId: appleIDCredential.user,
            email: email,
            firstName: appleIDCredential.fullName?.givenName,
            lastName: appleIDCredential.fullName?.familyName
          )
        }
      }

      guard let email = appleIDCredential.email ?? appleSignInInfo?.email else {
        print("Error trying to sign in -- no email ever.")
        return
      }
      Task {
        do {
          let firstName = appleIDCredential.fullName?.givenName ?? ""
          let lastName = appleIDCredential.fullName?.familyName
          let token = try await api.signInViaApple(
            identityToken,
            email,
            authCode,
            firstName,
            lastName)
          $auth.withLock { $0 = Auth(jwtToken: token) }
          await analytics.track(.signInCompleted(method: .apple, userId: appleIDCredential.user))
          self.navigationCoordinator.activePath = .listen
        } catch {
          print("Sign in failed: \(error)")
          await analytics.track(.signInFailed(method: .apple, error: error.localizedDescription))
        }
      }
    case let .failure(error):
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
        Task {
          do {
            let token = try await self.api.signInViaGoogle(serverAuthCode)
            self.$auth.withLock { $0 = Auth(jwtToken: token) }
            await self.analytics.track(
              .signInCompleted(method: .google, userId: signInResult.user.userID ?? "unknown"))
            self.navigationCoordinator.activePath = .listen
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
