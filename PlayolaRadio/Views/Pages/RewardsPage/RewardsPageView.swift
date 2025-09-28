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

struct RewardsPageView: View {
  @State private var listeningTileModel = ListeningTimeTileModel()
  @Bindable var model: RewardsPageModel

  var body: some View {
    VStack(spacing: 0) {
      // Sticky Title
      HStack {
        Text("Listener Rewards")
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)
      .background(Color.black)

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
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
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.white)
                .lineLimit(nil)
            }
            .padding(.horizontal, 20)

            // Reward Items
            LazyVStack(spacing: 1) {
              ForEach(Array(model.prizeTiers.enumerated()), id: \.element.id) { index, prizeTier in
                PrizeTierRow(
                  tier: index + 1,
                  prizeTier: prizeTier,
                  status: model.redemptionStatus(for: prizeTier),
                  onRedeem: {
                    Task { await model.redeemPrize(for: prizeTier) }
                  }
                )
              }
            }
            .background(Color(white: 0.08))
            .cornerRadius(12)
          }
        }
        .padding(.bottom, 100)  // Account for tab bar
      }
    }
    .background(Color.black)
    .task {
      await model.onViewAppeared()
    }
  }
}

// MARK: - Preview

struct RewardsPageView_Previews: PreviewProvider {
  static var previews: some View {
    RewardsPageView(model: RewardsPageModel())
      .background(Color.black)
  }
}
