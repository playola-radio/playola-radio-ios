import SDWebImageSwiftUI
import SwiftUI

struct GiveawayWinnerSheetView: View {
  @Bindable var model: GiveawayWinnerSheetModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      GiveawayWinnerFormView(model: model)
        .opacity(model.formOpacity)
        .allowsHitTesting(model.formInteractive)

      GiveawayWinnerClaimedView(model: model)
        .opacity(model.claimedOpacity)
        .allowsHitTesting(model.claimedInteractive)
    }
    .task { await model.task() }
  }
}

private struct GiveawayWinnerFormView: View {
  @Bindable var model: GiveawayWinnerSheetModel

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        WebImage(url: model.prizeImageUrl)
          .resizable()
          .scaledToFill()
          .frame(width: 160, height: 160)
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .padding(.top, 24)

        Text(model.headline)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text(model.prizeName)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text(model.prizeDescriptionText)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .multilineTextAlignment(.center)

        VStack(spacing: 12) {
          GiveawayWinnerField(
            label: model.fullNameLabel, placeholder: "", text: $model.fullName)
          GiveawayWinnerField(
            label: model.addressLine1Label, placeholder: model.addressLine1Placeholder,
            text: $model.addressLine1)
          GiveawayWinnerField(
            label: model.addressLine2Label, placeholder: "", text: $model.addressLine2)
          GiveawayWinnerField(
            label: model.cityLabel, placeholder: model.cityPlaceholder, text: $model.city)
          HStack(spacing: 12) {
            GiveawayWinnerField(
              label: model.stateLabel, placeholder: model.statePlaceholder, text: $model.state)
            GiveawayWinnerField(
              label: model.postalCodeLabel, placeholder: model.postalCodePlaceholder,
              text: $model.postalCode)
          }
        }
        .padding(.top, 8)

        Text(model.submitErrorText)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaRed)
          .multilineTextAlignment(.center)
          .opacity(model.submitErrorOpacity)

        Button(action: { Task { await model.claimButtonTapped() } }) {
          Text(model.claimButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.playolaRed))
        }
        .disabled(model.claimButtonDisabled)
        .opacity(model.claimButtonOpacity)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
  }
}

private struct GiveawayWinnerField: View {
  let label: String
  let placeholder: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(Color(hex: "#868686"))
      TextField(placeholder, text: $text)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#1A1A1A")))
    }
  }
}

private struct GiveawayWinnerClaimedView: View {
  let model: GiveawayWinnerSheetModel

  var body: some View {
    VStack(spacing: 12) {
      Text("🎉")
        .font(.system(size: 48))
      Text(model.claimedTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
        .foregroundColor(.white)
      Text(model.claimedSubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(Color(hex: "#C7C7C7"))

      Button(action: { model.closeButtonTapped() }) {
        Text(model.closeButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(RoundedRectangle(cornerRadius: 14).fill(Color.playolaRed))
      }
      .padding(.top, 24)
      .padding(.horizontal, 24)
    }
    .padding(.horizontal, 24)
  }
}

#if DEBUG
  #Preview("Winner — Nth tapper") {
    GiveawayWinnerSheetView(
      model: GiveawayWinnerSheetModel(
        participation: GiveawayParticipation(
          id: "e", stationId: "s", prizeName: "Two tickets to Reckless Kelly at the Heights",
          prizeDescription: "Friday night, doors at 8.", winningNumber: 9, tapNumber: 9,
          status: .resolvedWon(submissionCompleted: false), tappedAt: Date()),
        onClose: {}))
  }

  #Preview("Winner — promoted") {
    GiveawayWinnerSheetView(
      model: GiveawayWinnerSheetModel(
        participation: GiveawayParticipation(
          id: "e", stationId: "s", prizeName: "Two tickets to Reckless Kelly at the Heights",
          prizeDescription: "Friday night, doors at 8.", winningNumber: 9, tapNumber: 5,
          status: .resolvedWon(submissionCompleted: false), tappedAt: Date()),
        onClose: {}))
  }
#endif
