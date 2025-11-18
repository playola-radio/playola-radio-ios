//
//  LiveNowBadge.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/15/25.
//

import SwiftUI

struct LiveNowBadge: View {
  var body: some View {
    HStack(spacing: 8) {
      Image("MicrophoneForNowPlaying")
        .resizable()
        .renderingMode(.template)
        .foregroundColor(Color(hex: "#FF5252"))
        .frame(width: 10, height: 15)

      Text("LIVE NOW!")
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(Color(hex: "#FF5252"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(red: 0.3, green: 0.1, blue: 0.1))
    .cornerRadius(12)
  }
}

#Preview {
  LiveNowBadge()
    .padding()
    .background(Color.black)
}
