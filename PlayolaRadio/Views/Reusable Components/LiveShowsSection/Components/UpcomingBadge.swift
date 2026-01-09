//
//  UpcomingBadge .swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/15/25.
//

import SwiftUI

struct UpcomingBadge: View {
  var text: String = "UPCOMING LIVE SHOW"

  var body: some View {
    HStack(spacing: 8) {
      Text(text)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(Color(hex: "##FFC107"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#3D3420"))
    .cornerRadius(12)
  }
}

#Preview {
  VStack(spacing: 16) {
    UpcomingBadge()
    UpcomingBadge(text: "Mondays at 4pm")
    UpcomingBadge(text: "Wednesdays and Fridays at 8pm")
  }
  .padding()
  .background(Color.black)
}
