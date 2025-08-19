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
      Spacer()

      // Logo and branding
      VStack(spacing: 32) {
        // Playola logo with text
        Image("PlayolaLogo")
          .resizable()
          .scaledToFit()
          .frame(height: 120)

        VStack(spacing: 16) {
          Text("Invite only, for now!")
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

          Text("Discover music through independent artist-\nmade radio stations")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(Color(hex: "#C7C7C7"))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
        }
      }

      Spacer()

      // Form section
      VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Enter invite code")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)

          TextField("", text: $model.invitationCode)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "#333333"))
            .cornerRadius(6)
            .foregroundColor(.white)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .autocapitalization(.allCharacters)
            .disableAutocorrection(true)

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
          .padding(.vertical, 18)
          .background(Color.playolaRed)
          .cornerRadius(6)
        }

        VStack(spacing: 16) {
          Text("Don't have an invite code?")
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(.white)

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
            .padding(.vertical, 18)
            .background(Color.clear)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(.white, lineWidth: 1)
            )
          }
        }
      }
      .padding(.horizontal, 24)

      Spacer()
    }
    .background(Color.black)
  }
}

#Preview {
  InvitationCodePageView(model: InvitationCodePageModel())
}
