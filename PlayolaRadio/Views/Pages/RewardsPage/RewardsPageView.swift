//
//  RewardsPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import SwiftUI

enum RedemptionStatus {
  case redeemed
  case redeemable
  case moreTimeRequired(Int)
}

struct RewardTierRow: View {
  let tier: Int
  let name: String
  let iconName: String
  let hours: Int
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

        Image(iconName)
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

        Text(name)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(isRedeemed ? Color(hex: "#999999") : .white)
          .fixedSize(horizontal: true, vertical: false)

        Text("\(hours) \(hours == 1 ? "hour" : "hours")")
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

struct RewardsPageView: View {
  @State private var listeningTileModel = ListeningTimeTileModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Title
        HStack {
          Text("Listener Rewards")
            .font(.custom("Inter_700_Bold", size: 28))
            .foregroundColor(.white)
          Spacer()
        }
        .padding(.horizontal, 20)

        // Listening Time Tile
        VStack {
          ListeningTimeTile(model: listeningTileModel)
        }
        .padding(.horizontal, 20)

        // Your Rewards Section
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Your rewards")
              .font(.custom("Inter_700_Bold", size: 24))
              .foregroundColor(.white)

            Text("Earn rewards from your fav artists for being an early Playola listener!")
              .font(.custom("Inter_500_Medium", size: 16))
              .foregroundColor(.white)
              .lineLimit(nil)
          }
          .padding(.horizontal, 20)

          // Reward Items
          LazyVStack(spacing: 1) {
            RewardTierRow(
              tier: 1,
              name: "Koozie",
              iconName: "koozie-icon",
              hours: 10,
              status: .redeemed,
              onRedeem: { print("Redeeming Koozie") }
            )

            RewardTierRow(
              tier: 2,
              name: "T-Shirt",
              iconName: "tshirt-icon",
              hours: 30,
              status: .redeemable,
              onRedeem: { print("Redeeming T-Shirt") }
            )

            RewardTierRow(
              tier: 3,
              name: "Show Tix",
              iconName: "ticket-icon",
              hours: 70,
              status: .moreTimeRequired(40),
              onRedeem: { print("Redeeming Show Tix") }
            )

            RewardTierRow(
              tier: 4,
              name: "Meet & Greet",
              iconName: "handshake-icon",
              hours: 150,
              status: .moreTimeRequired(120),
              onRedeem: { print("Redeeming Meet & Greet") }
            )
          }
          .background(Color(white: 0.08))
          .cornerRadius(12)
          .padding(.horizontal, 20)
        }
      }
      .padding(.top, 20)
      .padding(.bottom, 100)  // Account for tab bar
    }
    .background(Color.black)
  }
}

// MARK: - Preview
struct RewardsPageView_Previews: PreviewProvider {
  static var previews: some View {
    RewardsPageView()
      .background(Color.black)
  }
}
