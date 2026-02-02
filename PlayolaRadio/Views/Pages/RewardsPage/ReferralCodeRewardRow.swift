//
//  ReferralCodeRewardRow.swift
//  PlayolaRadio
//

import SwiftUI

struct ReferralCodeRewardRow: View {
  let label: String
  let name: String
  let requiredHoursLabel: String
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

        Image(systemName: "person.2.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 28, height: 28)
          .foregroundColor(
            isRedeemed ? Color(red: 153 / 255, green: 153 / 255, blue: 153 / 255) : .white)
      }

      // Content
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(label)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white.opacity(0.6))
          Spacer()
        }

        Text(name)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white)
          .fixedSize(horizontal: true, vertical: false)

        Text(requiredHoursLabel)
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

          Text("\(hoursToGo) \(hoursToGo == 1 ? "hour" : "hours") to go")
            .lineLimit(1)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 20)
    .background(Color.black)
    .cornerRadius(12)
  }
}

// MARK: - Preview
struct ReferralCodeRewardRow_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 1) {
      ReferralCodeRewardRow(
        label: "Early Bird",
        name: "Referral Code",
        requiredHoursLabel: "2 hours",
        status: .redeemable,
        onRedeem: {})

      ReferralCodeRewardRow(
        label: "Early Bird",
        name: "Referral Code",
        requiredHoursLabel: "2 hours",
        status: .moreTimeRequired(1),
        onRedeem: {})

      ReferralCodeRewardRow(
        label: "Early Bird",
        name: "Referral Code",
        requiredHoursLabel: "2 hours",
        status: .redeemed,
        onRedeem: {})
    }
    .background(Color(white: 0.08))
  }
}
