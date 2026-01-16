//
//  FeedbackSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct FeedbackSheetView: View {
  @Bindable var model: FeedbackSheetModel
  @FocusState private var isTextFieldFocused: Bool

  private let placeholderText = """
    Found a bug?
    Have an idea for a new feature?
    Just want to say hi to the team?

    We would LOVE to hear from you for any reason at all...
    """

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
          Text("Send us a message and we'll get back to you as soon as we can!")
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          ZStack(alignment: .topLeading) {
            if model.message.isEmpty {
              Text(placeholderText)
                .font(.custom(FontNames.Inter_400_Regular, size: 16))
                .foregroundColor(Color(hex: "#666666"))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            TextEditor(text: $model.message)
              .font(.custom(FontNames.Inter_400_Regular, size: 16))
              .foregroundColor(.white)
              .scrollContentBackground(.hidden)
              .padding(8)
              .focused($isTextFieldFocused)
          }
          .frame(height: 150)
          .background(Color(hex: "#1A1A1A"))
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color(hex: "#333333"), lineWidth: 1)
          )
          .padding(.horizontal)

          Spacer()

          Button {
            Task {
              await model.send()
            }
          } label: {
            if model.isSending {
              ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            } else {
              Text("Send Message")
                .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
          }
          .background(model.canSend ? Color.playolaRed : Color(hex: "#666666"))
          .cornerRadius(8)
          .disabled(!model.canSend)
          .padding(.horizontal)
          .padding(.bottom)
        }
        .padding(.top, 20)
      }
      .navigationTitle("Contact Us")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(Color.black, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            model.cancel()
          }
          .foregroundColor(.white)
        }
      }
    }
    .presentationDetents([.medium])
    .onAppear {
      isTextFieldFocused = true
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}
