//
//  UpcomingGiveawayBadge.swift
//  PlayolaRadio
//

import SwiftUI

/// "Coming up" giveaway badge. Styled to match `LiveBadge` so it can sit alongside it on station
/// rows and Home cards. Purple so it reads as distinct from the green/red LIVE badge.
struct UpcomingGiveawayBadge: View {
  @State private var isPulsing = false

  private let badgeColor = Color.purple
  private var badgeText: String { "🎁 GIVEAWAY" }

  var body: some View {
    Text(badgeText)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
      .foregroundColor(badgeColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.black.opacity(0.7))
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(badgeColor, lineWidth: 1)
      )
      .shadow(color: badgeColor.opacity(isPulsing ? 0.8 : 0.3), radius: isPulsing ? 8 : 2)
      .opacity(isPulsing ? 1.0 : 0.7)
      .onAppear {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
          isPulsing = true
        }
      }
  }
}

#Preview("Upcoming Giveaway") {
  UpcomingGiveawayBadge()
    .preferredColorScheme(.dark)
}
