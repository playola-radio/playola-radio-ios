//
//  RedeemPrizeSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct RedeemPrizeSheetView: View {
  @Bindable var model: RedeemPrizeSheetModel

  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 24) {
        // Prize selection
        VStack(alignment: .leading, spacing: 12) {
          Text(model.choosePrizeLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)

          ForEach(model.redeemOptions) { option in
            Button {
              model.optionTapped(option)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: model.isSelected(option) ? "checkmark.circle.fill" : "circle")
                  .foregroundColor(model.isSelected(option) ? .green : .gray)
                  .font(.system(size: 22))

                Text(option.name)
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)

                Spacer()
              }
              .padding(.vertical, 12)
              .padding(.horizontal, 16)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(model.isSelected(option) ? Color.white.opacity(0.1) : Color.clear)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(
                    model.isSelected(option) ? Color.white.opacity(0.3) : Color.white.opacity(0.1),
                    lineWidth: 1)
              )
            }
          }
        }

        if model.needsEmail {
          VStack(alignment: .leading, spacing: 8) {
            Text(model.emailLabel)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
              .foregroundColor(.white)

            TextField(model.emailPlaceholder, text: $model.emailAddress)
              .textContentType(.emailAddress)
              .keyboardType(.emailAddress)
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .padding(12)
              .background(Color.white.opacity(0.1))
              .cornerRadius(8)
              .foregroundColor(.white)
          }
        }

        Spacer()

        // Submit button
        Button {
          Task { await model.submitButtonTapped() }
        } label: {
          HStack {
            if model.isSubmitting {
              ProgressView()
                .tint(.white)
            }
            Text(model.submitButtonText)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(model.canSubmit ? Color(red: 0.8, green: 0.4, blue: 0.4) : Color.gray)
          .foregroundColor(.white)
          .cornerRadius(10)
        }
        .disabled(!model.canSubmit)
      }
      .padding(20)
      .background(Color.black)
      .navigationTitle(model.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(model.cancelButtonText) {
            model.cancelButtonTapped()
          }
          .foregroundColor(.white)
        }
      }
      .toolbarBackground(Color.black, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
    }
    .playolaAlert($model.presentedAlert)
  }
}
