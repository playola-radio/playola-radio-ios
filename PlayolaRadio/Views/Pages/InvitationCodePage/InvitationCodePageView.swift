//
//  InvitationCodePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import SwiftUI

struct InvitationCodePageView: View {
  @Bindable var model: InvitationCodePageModel

  var body: some View {
    VStack(spacing: 0) {

      // Logo and branding
      VStack(spacing: 32) {
        // Playola logo with text
        Image("PlayolaLogo")
          .resizable()
          .scaledToFit()
          .frame(height: 156)
          .padding(.top, 16)

        VStack(spacing: 16) {
          Text("Invite only, for now!")
            .font(.custom(FontNames.Inter_700_Bold, size: 26))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.top, 20)

          Text("Discover music through independent artist-\nmade radio stations")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(Color(hex: "#C7C7C7"))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
        }
        //        .padding(.horizontal, 38)
      }

      // Form section
      VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Enter invite code")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)

          TextField("", text: $model.invitationCode)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "#333333"))
            .cornerRadius(6)
            .foregroundColor(.white)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .autocapitalization(.allCharacters)
            .disableAutocorrection(true)
            .frame(minHeight: 48)

          // Error message
          if let errorMessage = model.errorMessage {
            HStack {
              Image(systemName: "exclamationmark.circle")
                .foregroundColor(.playolaRed)
                .font(.system(size: 14))

              Text(errorMessage)
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.playolaRed)

              Spacer()
            }
          }
        }

        // Sign in button
        Button(action: {
          Task {
            await model.signInButtonTapped()
          }
        }) {
          HStack {
            Image("KeyHorizontal")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white)

            Text("Sign in")
              .font(.custom(FontNames.Inter_500_Medium, size: 16))
              .foregroundColor(.white)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.playolaRed)
          .cornerRadius(6)
        }

        VStack(spacing: 16) {
          Text("Don't have an invite code?")
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(Color(hex: "#C7C7C7"))

          // Join waitlist button
          Button(action: {
            Task {
              await model.joinWaitlistButtonTapped()
            }
          }) {
            HStack {
              Image(systemName: "envelope")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

              Text("Join waitlist")
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "#827876"), lineWidth: 1)
            )
          }
        }
        .padding(.top, 8)
      }
      .padding(.horizontal, 24)
      .padding(.top, 32)

      Spacer()
    }
    .background(Color(hex: "#130000"))
  }
}

#Preview {
  InvitationCodePageView(model: InvitationCodePageModel())
}
