//
//  ClaimSheetContent.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct ClaimSheetContent: View {
  @Environment(\.displayScale) private var displayScale
  @Bindable var model: ClaimSheetModel

  var body: some View {
    VStack(spacing: 0) {
      switch model.phase {
      case .sent:
        sentMessage
      case .form, .sending, .sendFailed:
        hero
        form
      case .notYetClaimed, .noLongerOpen, .nothingToFillIn:
        hero
        Spacer(minLength: 0)
      case .claiming:
        hero
        loading
      }
      actions
    }
  }

  private var hero: some View {
    VStack(spacing: 10) {
      prizeImage
      pill
      Text(model.prizeTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
        .foregroundColor(.playolaTextPrimary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
      subtitle
    }
    .padding(EdgeInsets(top: 16, leading: 24, bottom: 8, trailing: 24))
  }

  @ViewBuilder private var prizeImage: some View {
    if model.prizeImageUrl != nil {
      WebImage(
        url: model.prizeImageUrl,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 120, height: 120), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 120, height: 120)
      .background(Color.playolaSurfaceSection)
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .opacity(model.prizeImageOpacity)
      .accessibilityHidden(true)
    }
  }

  @ViewBuilder private var subtitle: some View {
    if model.isSubtitleShown {
      Text(model.subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder private var pill: some View {
    if model.isHeaderPillShown {
      HStack(spacing: 6) {
        Image(systemName: model.headerPillSymbol)
          .font(.system(size: 13, weight: .bold))
        Text(model.headerPill)
          .font(.custom(FontNames.Inter_700_Bold, size: 11))
          .tracking(1)
      }
      .foregroundColor(.playolaGiveawayPurple)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Capsule().fill(Color.playolaGiveawayPurple.opacity(0.2)))
    }
  }

  private var form: some View {
    VStack(spacing: 24) {
      ForEach(model.fields) { field in
        ClaimFieldView(field: field)
      }
    }
    .padding(EdgeInsets(top: 16, leading: 24, bottom: 8, trailing: 24))
    .opacity(model.fieldsOpacity)
    .disabled(!model.areFieldsEnabled)
  }

  private var loading: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.playolaTextSecondary)
        .scaleEffect(1.4)
      Text(model.loadingText)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var sentMessage: some View {
    VStack(spacing: 14) {
      Image(systemName: "checkmark")
        .font(.system(size: 30, weight: .bold))
        .foregroundColor(.playolaSuccessGreen)
        .frame(width: 72, height: 72)
        .background(Circle().fill(Color.playolaSuccessGreen.opacity(0.15)))
        .accessibilityHidden(true)
      Text(model.sentTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.playolaTextPrimary)
        .multilineTextAlignment(.center)
      Text(model.sentSubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(3)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var actions: some View {
    VStack(spacing: 4) {
      VStack(spacing: 10) {
        hint
        errorBanner
        primaryButton
      }
      laterButton
    }
    .padding(EdgeInsets(top: 16, leading: 24, bottom: 34, trailing: 24))
  }

  @ViewBuilder private var hint: some View {
    if let hintText = model.incompleteHintText, model.isPrimaryButtonMuted {
      Text(hintText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.playolaTextTertiary)
    }
  }

  @ViewBuilder private var errorBanner: some View {
    if !model.errorText.isEmpty {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "exclamationmark.circle")
          .font(.system(size: 18))
          .foregroundColor(.playolaSystemRed)
        Text(model.errorText)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaTextPrimary)
          .lineSpacing(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .background(RoundedRectangle(cornerRadius: 10).fill(Color.playolaSystemRed.opacity(0.12)))
      .overlay(
        RoundedRectangle(cornerRadius: 10).stroke(Color.playolaSystemRed.opacity(0.4), lineWidth: 1)
      )
    }
  }

  @ViewBuilder private var primaryButton: some View {
    if model.isPrimaryButtonShown {
      primaryButtonBody
    }
  }

  private var primaryButtonBody: some View {
    Button {
      Task { await model.primaryButtonTapped() }
    } label: {
      HStack(spacing: 10) {
        busyIndicator
        Text(model.primaryButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
      }
      .foregroundColor(model.isPrimaryButtonMuted ? .playolaTextTertiary : .white)
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(model.isPrimaryButtonMuted ? Color.playolaSurfaceRaised : Color.playolaRed)
      )
      .opacity(model.isPrimaryButtonBusy ? 0.7 : 1)
    }
    .disabled(!model.isPrimaryButtonEnabled)
  }

  @ViewBuilder private var busyIndicator: some View {
    if model.isPrimaryButtonBusy {
      ProgressView().tint(.white)
    }
  }

  @ViewBuilder private var laterButton: some View {
    if model.isLaterShown {
      Button {
        model.laterTapped()
      } label: {
        Text(model.laterButtonTitle)
          .font(.custom(FontNames.Inter_500_Medium, size: 15))
          .foregroundColor(.playolaTextSecondary)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .opacity(model.laterButtonOpacity)
      }
      .disabled(!model.isLaterAvailable)
    }
  }
}
