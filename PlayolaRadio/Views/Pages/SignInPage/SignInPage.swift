//
//  SignInPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
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
  
  // MARK: State
  
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
        $appleSignInInfo.withLock { $0 = AppleSignInInfo(
          appleUserId: appleIDCredential.user, email: email, displayName: appleIDCredential.fullName?.formatted()
        ) }
      }
      
      guard let email = appleIDCredential.email ?? appleSignInInfo?.email else {
        print("Error trying to sign in -- no email ever.")
        return
      }
      Task {
        await API().signInViaApple(identityToken: identityToken,
                                   email: email,
                                   authCode: authCode,
                                   displayName: appleIDCredential.fullName?.formatted())
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
        Task { await API().signInViaGoogle(code: serverAuthCode) }
      }
    }
  }
  
  func logOutButtonTapped() {
    $auth.withLock { $0 = Auth() }
    Task { await API().revokeAppleCredentials(appleUserId: "000014.59c02331e3a642fd8bebedd86d191ed3.1758") }
  }
}

@MainActor
struct SignInPage: View {
  var model: SignInPageModel
  
  var body: some View {
    NavigationView {
      ZStack {
        VStack {
          Spacer()
          Image("LogoMark")
            .resizable()
            .scaledToFit()
            .padding(100)
          
          if model.auth.isLoggedIn {
            Button {
              model.logOutButtonTapped()
            } label: {
              Text("Log Out")
            }
          } else {
            SignInWithAppleButton(.signIn) { request in
              model.signInWithAppleButtonTapped(request: request)
            } onCompletion: { result in
              model.signInWithAppleCompleted(result: result)
            }.signInWithAppleButtonStyle(.white)
              .frame(height: 60)
              .padding([.leading, .trailing], 20)
              .padding()
            
            Spacer()
            
            GoogleSignInButton {
              model.signInWithGoogleButtonTapped()
            }
            .frame(height: 60)
            .padding([.leading, .trailing], 20)
            .padding()
          }
          
          Spacer()
          Spacer()
        }
        
      }.background(Color.black)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
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
