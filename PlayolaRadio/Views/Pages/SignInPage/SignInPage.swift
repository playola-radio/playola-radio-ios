//
//  SignInPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
//
import AuthenticationServices
import Dependencies
import GoogleSignIn
import GoogleSignInSwift
import Sharing
import SwiftUI

@MainActor
@Observable
class SignInPageModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.appleSignInInfo) var appleSignInInfo: AppleSignInInfo?
  @ObservationIgnored @Shared(.auth) var auth: Auth
  var navigationCoordinator: NavigationCoordinator

  init(navigationCoordinator: NavigationCoordinator = .shared) {
    self.navigationCoordinator = navigationCoordinator
  }

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
        print("Error decoding signin info from apple")
        return
      }
      if appleIDCredential.user != appleSignInInfo?.appleUserId,
        let email = appleIDCredential.email
      {
        $appleSignInInfo.withLock {
          $0 = AppleSignInInfo(
            appleUserId: appleIDCredential.user, email: email,
            displayName: appleIDCredential.fullName?.formatted()
          )
        }
      }

      guard let email = appleIDCredential.email ?? appleSignInInfo?.email else {
        print("Error trying to sign in -- no email ever.")
        return
      }
      Task {
        do {
          let token = try await api.signInViaApple(
            identityToken,
            email,
            authCode,
            appleIDCredential.fullName?.formatted())
          $auth.withLock { $0 = Auth(jwtToken: token) }
          self.navigationCoordinator.activePath = .listen
        } catch {
          print("Sign in failed: \(error)")
        }
      }
    case let .failure(error):
      print(error)
    }
  }

  func signInWithGoogleButtonTapped() {
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
            self.navigationCoordinator.activePath = .listen
          } catch {
            print("Google sign in failed: \(error)")
          }
        }
      }
    }
  }

  func logOutButtonTapped() {
    $auth.withLock { $0 = Auth() }
    Task {
      //      await API().revokeAppleCredentials(
      //        appleUserId: "000014.59c02331e3a642fd8bebedd86d191ed3.1758")
    }
  }
}

@MainActor
struct SignInPage: View {
  var model: SignInPageModel

  var body: some View {
    NavigationView {
      ZStack {
        // Background gradient
        LinearGradient(
          gradient: Gradient(colors: [Color.black, Color(hex: "#1C1C1E")]),
          startPoint: .top,
          endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)

        VStack(spacing: 30) {
          Spacer()

          // Logo section
          VStack(spacing: 15) {
            Image("LogoMark")
              .resizable()
              .scaledToFit()
              .frame(height: 80)

            Image("PlayolaWordLogo")
              .resizable()
              .scaledToFit()
              .frame(width: 180)
          }
          .padding(.bottom, 40)

          // Welcome text
          Text("Welcome to Playola")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)

          Text("Sign in to access your personalized radio stations")
            .font(.subheadline)
            .foregroundColor(Color.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)

          if model.auth.isLoggedIn {
            // Logged in state
            VStack(spacing: 15) {
              Text("You're signed in")
                .font(.headline)
                .foregroundColor(.white)

              Button {
                model.logOutButtonTapped()
              } label: {
                Text("Sign Out")
                  .fontWeight(.semibold)
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .frame(height: 56)
                  .background(Color.playolaRed)
                  .cornerRadius(12)
                  .padding(.horizontal, 30)
              }
            }
          } else {
            // Auth buttons
            VStack(spacing: 16) {
              SignInWithAppleButton(.signIn) { request in
                model.signInWithAppleButtonTapped(request: request)
              } onCompletion: { result in
                model.signInWithAppleCompleted(result: result)
              }
              .signInWithAppleButtonStyle(.white)
              .frame(height: 56)
              .cornerRadius(12)
              .padding(.horizontal, 30)

              CustomGoogleSignInButton {
                model.signInWithGoogleButtonTapped()
              }
              .padding(.horizontal, 30)
            }
          }

          Spacer()

          // Footer
          VStack(spacing: 8) {
            Text("By signing in, you agree to our")
              .font(.footnote)
              .foregroundColor(Color.white.opacity(0.6))

            HStack(spacing: 4) {
              Text("Terms of Service")
                .font(.footnote)
                .foregroundColor(.playolaRed)
                .underline()

              Text("and")
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.6))

              Text("Privacy Policy")
                .font(.footnote)
                .foregroundColor(.playolaRed)
                .underline()
            }
          }
          .padding(.bottom, 20)
        }
        .padding()
      }
      .navigationBarHidden(true)
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

struct CustomGoogleSignInButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Image("google-icon")  // Make sure you have this asset in your asset catalog
          .resizable()
          .scaledToFit()
          .frame(width: 24, height: 24)

        Text("Sign in with Google")
          .fontWeight(.semibold)
          .foregroundColor(.black)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.white)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.gray.opacity(0.3), lineWidth: 1)
      )
    }
  }
}

#Preview {
  NavigationStack {
    SignInPage(model: SignInPageModel())
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }
}
