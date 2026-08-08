//
//  SignInPadView.swift
//  PlayolaRadio
//
//  iPad-only (regular horizontal size class) layout for the Sign In screen.
//
//  QUARANTINED ON PURPOSE. iPad is not a maintained priority. This view is a dumb
//  layout over `SignInPageModel` — it holds zero business logic and reuses only the
//  shared `CustomGoogleSignInButton` plus the system `SignInWithAppleButton`, wiring
//  both to the same model actions the compact layout uses. It deliberately duplicates
//  the small card styling rather than sharing components with the iPhone layout, so
//  future iPhone changes never have to account for iPad. Design drift is acceptable;
//  this whole file can be deleted without touching the iPhone path. See
//  docs/superpowers/specs/2026-08-06-ipad-sign-in-design.md.
//

import AuthenticationServices
import SwiftUI

struct SignInPadView: View {
  @Bindable var model: SignInPageModel

  var body: some View {
    ZStack {
      LinearGradient(
        gradient: Gradient(colors: [Color.black, Color(hex: "#1C1C1E")]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      card
        .frame(width: 460)
    }
  }

  // MARK: - Centered auth card

  private var card: some View {
    VStack(spacing: 32) {
      logo
      welcome
      authButtons
      footer
    }
    .padding(40)
    .frame(maxWidth: .infinity)
    .background(Color.white.opacity(0.05))
    .clipShape(.rect(cornerRadius: 24))
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  private var logo: some View {
    VStack(spacing: 16) {
      Image("LogoMark")
        .resizable()
        .scaledToFit()
        .frame(height: 96)

      Image("PlayolaWordLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 220)
    }
    .padding(.bottom, 8)
  }

  private var welcome: some View {
    VStack(spacing: 12) {
      Text(model.welcomeTitle)
        .font(.system(size: 32, weight: .bold))
        .foregroundColor(.white)

      Text(model.welcomeSubtitle)
        .font(.system(size: 17))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
  }

  private var authButtons: some View {
    VStack(spacing: 16) {
      CustomGoogleSignInButton(title: model.googleSignInButtonTitle) {
        Task { await model.signInWithGoogleButtonTapped() }
      }

      SignInWithAppleButton(.signIn) { request in
        model.signInWithAppleButtonTapped(request: request)
      } onCompletion: { result in
        Task { await model.signInWithAppleCompleted(result: result) }
      }
      .signInWithAppleButtonStyle(.white)
      .frame(height: 56)
      .cornerRadius(12)
    }
  }

  private var footer: some View {
    VStack(spacing: 8) {
      Text(model.termsAgreementText)
        .font(.footnote)
        .foregroundColor(Color.white.opacity(0.6))

      HStack(spacing: 4) {
        Text(model.termsOfServiceText)
          .font(.footnote)
          .foregroundColor(.playolaRed)
          .underline()

        Text(model.termsConjunctionText)
          .font(.footnote)
          .foregroundColor(Color.white.opacity(0.6))

        Text(model.privacyPolicyText)
          .font(.footnote)
          .foregroundColor(.playolaRed)
          .underline()
      }
    }
    .padding(.top, 8)
  }
}

#Preview(traits: .fixedLayout(width: 1024, height: 768)) {
  SignInPadView(model: SignInPageModel())
    .preferredColorScheme(.dark)
}
