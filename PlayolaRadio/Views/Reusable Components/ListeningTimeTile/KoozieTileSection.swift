//
//  KoozieTileSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import SwiftUI

/// The koozie bottom-section of the Listening Time tile. Renders one of the five koozie
/// states off `model.mode`; all copy/behavior lives on the model. A reusable component
/// (not a page view), so the `switch` on `model.mode` is allowed.
struct KoozieTileSection: View {
  @Bindable var model: KoozieTileModel

  var body: some View {
    switch model.mode {
    case .inProgress: progressView
    case .claimable: claimableView
    case .addressForm:
      KoozieAddressFormView(
        form: model.addressForm,
        onBack: { model.backTapped() },
        onSend: { await model.sendMyKoozieTapped() })
    case .congrats: congratsView
    case .earned: earnedView
    }
  }

  // MARK: - In progress

  private var progressView: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        koozieIcon(background: Color.gray900)
        VStack(alignment: .leading, spacing: 4) {
          Text(model.progressTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(Color.textPrimary)
          Text(model.hoursToGoLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(Color.textSecondary)
        }
        Spacer()
        Text(model.progressPercentLabel)
          .font(.custom(FontNames.Inter_500_Medium, size: 13))
          .foregroundColor(Color.textSecondary)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.gray900)
          Capsule().fill(Color.playolaRed)
            .frame(width: geo.size.width * model.progressFraction)
        }
      }
      .frame(height: 6)
    }
  }

  // MARK: - Claimable

  private var claimableView: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        koozieIcon(background: Color.playolaRed)
        VStack(alignment: .leading, spacing: 4) {
          Text(model.claimableTitle)
            .font(.custom(FontNames.Inter_700_Bold, size: 16))
            .foregroundColor(.white)
          Text(model.claimableSubtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(Color.textSecondary)
        }
        Spacer()
      }
      Button(
        action: { model.redeemTapped() },
        label: {
          Text(model.redeemButtonText)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.playolaRed)
            .cornerRadius(8)
        })
    }
    .padding(16)
    .background(Color.elevatedSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Congrats

  private var congratsView: some View {
    HStack(alignment: .top, spacing: 12) {
      koozieIcon(background: Color.playolaRed)
      Text(model.congratsMessage)
        .font(.custom(FontNames.Inter_500_Medium, size: 15))
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Button(
        action: { Task { await model.dismissCongratsTapped() } },
        label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .foregroundColor(Color.textSecondary)
        })
    }
    .padding(16)
    .background(Color.elevatedSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Earned

  private var earnedView: some View {
    HStack(spacing: 12) {
      koozieIcon(background: Color.playolaRed, size: 28)
      Text(model.earnedText)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(Color.textSecondary)
      Spacer()
    }
    .padding(12)
    .background(Color.cardSurface)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Shared icon

  private func koozieIcon(background: Color, size: CGFloat = 40) -> some View {
    Image("koozie-icon")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .foregroundColor(.white)
      .frame(width: size * 0.5, height: size * 0.5)
      .frame(width: size, height: size)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

/// Inline "Where should we send it?" address form. Fields bind straight to the form model;
/// Back/Send are provided by the tile model. Reusable component, so the `if let` for the
/// inline error is acceptable.
struct KoozieAddressFormView: View {
  @Bindable var form: KoozieAddressFormModel
  let onBack: () -> Void
  let onSend: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(form.title)
        .font(.custom(FontNames.Inter_700_Bold, size: 16))
        .foregroundColor(.white)
      Text(form.subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(Color.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      field(form.fullNamePlaceholder, text: $form.fullName)
        .textContentType(.name)
      field(form.addressLine1Placeholder, text: $form.addressLine1)
        .textContentType(.fullStreetAddress)
      field(form.addressLine2Placeholder, text: $form.addressLine2)

      HStack(spacing: 8) {
        field(form.cityPlaceholder, text: $form.city)
        field(form.statePlaceholder, text: $form.state)
          .frame(width: 64)
          .textInputAutocapitalization(.characters)
        field(form.zipPlaceholder, text: $form.postalCode)
          .frame(width: 90)
          .keyboardType(.numbersAndPunctuation)
      }

      if let error = form.serverError {
        Text(error)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color.error)
      }

      HStack {
        Button(action: onBack) {
          Text(form.backButtonText)
            .font(.custom(FontNames.Inter_500_Medium, size: 15))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)
        }
        Spacer()
        Button(
          action: { Task { await onSend() } },
          label: {
            Text(form.submitButtonText)
              .font(.custom(FontNames.Inter_700_Bold, size: 16))
              .foregroundColor(.white)
              .padding(.vertical, 12)
              .padding(.horizontal, 20)
              .opacity(form.canSubmit ? 1.0 : 0.5)
          }
        )
        .disabled(!form.canSubmit)
      }
    }
    .padding(16)
    .background(Color.elevatedSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func field(_ placeholder: String, text: Binding<String>) -> some View {
    TextField("", text: text, prompt: Text(placeholder).foregroundColor(Color.textSecondary))
      .font(.custom(FontNames.Inter_400_Regular, size: 15))
      .foregroundColor(.white)
      .padding(10)
      .background(Color.cardSurface)
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
