//
//  ListeningTimeTile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

struct ListeningTimeTile: View {
  @Bindable var model: ListeningTimeTileModel

  let onRedeemRewards: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image("listening-time-icon")
          .foregroundColor(.white)

        Text("Listening Time")
          .font(.custom(FontNames.SpaceGrotesk_500_Medium, size: 16))
          .foregroundColor(.white)

        Spacer()
      }

      Text(model.listeningTimeDisplayString)
        .font(.custom(FontNames.Inter_700_Bold, size: 32))
        .foregroundColor(.white)

      if let buttonText = model.buttonText {
        Button(action: onRedeemRewards) {
          HStack {
            Spacer()
            Text(buttonText)
              .font(.custom(FontNames.Inter_500_Medium, size: 16))
              .foregroundColor(.white)
            Spacer()
          }
          .padding(.vertical, 16)
          .background(Color(red: 0.8, green: 0.4, blue: 0.4))
          .foregroundColor(.white)
          .cornerRadius(6)
        }
      }
    }
    .padding(20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
    .onAppear { model.viewAppeared() }
    .onDisappear { model.viewDisappeared() }
  }
}

// MARK: - Preview
#Preview {
  ListeningTimeTile(model: ListeningTimeTileModel())
    .padding()
    .background(Color.black)
}
