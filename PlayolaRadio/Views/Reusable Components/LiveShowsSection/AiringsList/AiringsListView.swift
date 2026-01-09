//
//  AiringsListView.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import PlayolaPlayer
import SwiftUI

struct AiringsListView: View {
  @Bindable var model: AiringsListModel
  var presentAlert: (PlayolaAlert) -> Void = { _ in }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(model.tileModels, id: \.airing.id) { tileModel in
          AiringTile(model: tileModel, presentAlert: presentAlert)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  let now = Date()
  let calendar = Calendar.current

  let mockAirings: [Airing] = [
    Airing.mockWith(
      id: "1",
      airtime: calendar.date(byAdding: .minute, value: -30, to: now)!
    ),
    Airing.mockWith(
      id: "2",
      airtime: calendar.date(byAdding: .day, value: 1, to: now)!
    ),
    Airing.mockWith(
      id: "3",
      airtime: calendar.date(byAdding: .day, value: 2, to: now)!
    ),
  ]

  VStack(alignment: .leading, spacing: 12) {
    Text("Live shows")
      .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
      .foregroundColor(.white)

    AiringsListView(model: AiringsListModel(airings: mockAirings))
  }
  .padding()
  .background(Color.black)
}
