//
//  InDevelopmentBadge.swift
//  PlayolaRadio

import SwiftUI

struct InDevelopmentBadge: View {
  let text: String?

  var body: some View {
    if let text {
      Text(text)
        .font(.custom(FontNames.Inter_700_Bold, size: 10))
        .tracking(1.4)
        .foregroundColor(.playolaRed)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(Color.playolaRed, lineWidth: 1)
        )
    }
  }
}

#Preview {
  InDevelopmentBadge(text: "IN DEVELOPMENT")
    .preferredColorScheme(.dark)
}
