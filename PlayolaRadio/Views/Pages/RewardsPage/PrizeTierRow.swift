import SDWebImageSwiftUI
//
//  PrizeTierRow.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/28/25.
//
import SwiftUI

struct PrizeTierRow: View {
  let tier: Int
  let prizeTier: PrizeTier
  let status: RedemptionStatus
  let onRedeem: () -> Void

  private var isRedeemed: Bool {
    if case .redeemed = status {
      return true
    }
    return false
  }

  var body: some View {
    HStack(spacing: 16) {
      // Icon
      ZStack {
        Circle()
          .fill(Color(white: 0.15))
          .frame(width: 56, height: 56)

        WebImage(url: prizeTier.imageIconUrl)
          .renderingMode(.template)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 28, height: 28)
          .foregroundColor(
            isRedeemed ? Color(red: 153 / 255, green: 153 / 255, blue: 153 / 255) : .white)
      }

      // Content
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Tier \(tier)")
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white.opacity(0.6))
          Spacer()
        }

        Text(prizeTier.name)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white)
          .fixedSize(horizontal: true, vertical: false)

        Text(
          "\(prizeTier.requiredListeningHours) \(prizeTier.requiredListeningHours == 1 ? "hour" : "hours")"
        )
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white.opacity(0.6))
      }

      Spacer()

      // Status/Action
      switch status {
      case .redeemed:
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .frame(width: 20, height: 20)
          Text("Redeemed")
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .foregroundColor(.white)
        }

      case .redeemable:
        Button(action: onRedeem) {
          Text("Redeem")
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(red: 0.8, green: 0.4, blue: 0.4))
            .cornerRadius(6)
        }

      case .moreTimeRequired(let hoursToGo):
        HStack(spacing: 4) {
          Image(systemName: "lock.fill")
            .foregroundColor(.white)
            .font(.system(size: 14))

          Text("\(hoursToGo) hours to go")
            .lineLimit(1)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 150, alignment: .trailing)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color.black)
    .cornerRadius(12)
  }
}

// MARK: - Preview
struct PrizeTierRow_Previews: PreviewProvider {
  static var previews: some View {
    PrizeTierRow(
      tier: 1,
      prizeTier: .mock,
      status: .redeemable,
      onRedeem: {})
  }
}
