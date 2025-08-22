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
struct SignInPage: View {
  @Bindable var model: SignInPageModel

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

          // Auth buttons
          VStack(spacing: 16) {
            SignInWithAppleButton(.signIn) { request in
              Task {
                await model.signInWithAppleButtonTapped(request: request)
              }
            } onCompletion: { result in
              model.signInWithAppleCompleted(result: result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .cornerRadius(12)
            .padding(.horizontal, 30)

            CustomGoogleSignInButton {
              Task {
                await model.signInWithGoogleButtonTapped()
              }
            }
            .padding(.horizontal, 30)
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
    .fullScreenCover(item: $model.presentedSheet) { item in
      switch item {
      case let .invitationCode(invitationModel):
        InvitationCodePageView(model: invitationModel)
      case .player:
        EmptyView()  // This case shouldn't occur in SignInPage
      }
    }
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
