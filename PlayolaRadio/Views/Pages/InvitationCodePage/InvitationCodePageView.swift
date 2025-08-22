//
//  InvitationCodePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import SwiftUI

struct InvitationCodePageView: View {
  @Bindable var model: InvitationCodePageModel

  // Keyboard focus for the single text field
  @FocusState private var isInputFocused: Bool

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
          Text(model.titleText)
            .font(.custom(FontNames.Inter_700_Bold, size: 26))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.top, 20)

          Text(model.attributedSubtitleText)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(Color(hex: "#C7C7C7"))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 38)
        }
      }

      // Form section
      VStack(spacing: 24) {
        if !model.shouldHideInput {
          VStack(alignment: .leading, spacing: 8) {
            Text(model.inputLabelTitleText)
              .font(.custom(FontNames.Inter_500_Medium, size: 16))
              .foregroundColor(.white)

            TextField("", text: $model.inputText)
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
              .focused($isInputFocused)  // ← bind focus to enable dismissals
              .submitLabel(.send)
              .onSubmit {
                Task { await model.actionButtonTapped() }
              }

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
        }

        // Action button
        Button(
          action: {
            Task { await model.actionButtonTapped() }
          },
          label: {
            HStack {
              Image(model.actionButtonImageName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

              Text(model.actionButtonText)
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.playolaRed)
            .cornerRadius(6)
          }
        )

        // Change mode section
        VStack(spacing: 16) {
          Text(model.changeModeLabelIntroText)
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(Color(hex: "#C7C7C7"))

          // Join waitlist button
          Button(
            action: {
              Task { await model.changeModeButtonTapped() }
            },
            label: {
              HStack {
                Image(model.changeModeButtonImageName)
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.white)

                Text(model.changeModeButtonText)
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
          )
        }
        .padding(.top, 8)
      }
      .padding(.horizontal, 24)
      .padding(.top, 32)

      Spacer()
    }
    .background(Color(hex: "#130000"))

    // 1) Tap anywhere outside the field to dismiss keyboard
    .contentShape(Rectangle())
    .onTapGesture {
      isInputFocused = false
    }

    // 2) Drag down anywhere to dismiss (simple, non-interactive)
    .simultaneousGesture(
      DragGesture(minimumDistance: 10)
        .onEnded { value in
          if value.translation.height > 30 { isInputFocused = false }
        }
    )

    // 3) Keyboard toolbar "Hide" button
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button {
          isInputFocused = false
        } label: {
          Image(systemName: "keyboard.chevron.compact.down")
          Text("Hide")
        }
      }
    }
    .sheet(isPresented: $model.showingShareSheet) {
      ShareSheet(items: [
        "https://apps.apple.com/us/app/playola-radio/id6480465361",
        "Playola: Discover music through artist-made radio stations.",
      ])
    }
  }
}

#Preview {
  InvitationCodePageView(model: InvitationCodePageModel())
}
