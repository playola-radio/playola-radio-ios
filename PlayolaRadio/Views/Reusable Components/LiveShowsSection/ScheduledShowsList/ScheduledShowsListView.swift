//
//  ScheduledShowsListView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import SwiftUI

struct ScheduledShowsListView: View {
  @Bindable var model: ScheduledShowsListModel
  // Workaround: SwiftUI does not propagate alerts through ScrollViews
  var presentAlert: (PlayolaAlert) -> Void = { _ in }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(model.tileModels, id: \.scheduledShow.id) { tileModel in
          ScheduledShowTile(model: tileModel, presentAlert: presentAlert)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  let now = Date()
  let calendar = Calendar.current

  let mockShows: [ScheduledShow] = [
    ScheduledShow.mockWith(
      id: "1",
      showId: "show1",
      airtime: calendar.date(byAdding: .minute, value: -30, to: now)!,
      show: Show.mockWith(title: "In the Van with the Stelly Band", durationMS: 120 * 60 * 1000)
    ),
    ScheduledShow.mockWith(
      id: "2",
      showId: "show2",
      airtime: calendar.date(byAdding: .day, value: 11, to: now)!,
      show: Show.mockWith(title: "Live with the Paladins", durationMS: 120 * 60 * 1000)
    ),
    ScheduledShow.mockWith(
      id: "3",
      showId: "show3",
      airtime: calendar.date(byAdding: .day, value: 2, to: now)!,
      show: Show.mockWith(title: "Midnight Jazz Session", durationMS: 180 * 60 * 1000)
    ),
  ]

  VStack(alignment: .leading, spacing: 12) {
    Text("Live shows")
      .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
      .foregroundColor(.white)

    ScheduledShowsListView(model: ScheduledShowsListModel(scheduledShows: mockShows))
  }
  .padding()
  .background(Color.black)
}
