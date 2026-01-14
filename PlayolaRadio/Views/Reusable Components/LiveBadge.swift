//
//  LiveBadge.swift
//  PlayolaRadio
//
//  Created by Brian Keane on 1/14/26.
//

import SwiftUI

struct LiveBadge: View {
  let status: LiveStatus
  @State private var isPulsing = false

  private var badgeColor: Color {
    status == .voicetracking ? .playolaRed : .green
  }

  private var badgeText: String { "LIVE NOW" }

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

#Preview("Voicetracking") {
  LiveBadge(status: .voicetracking)
    .preferredColorScheme(.dark)
}

#Preview("Show Airing") {
  LiveBadge(status: .showAiring)
    .preferredColorScheme(.dark)
}
