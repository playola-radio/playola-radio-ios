//
//  LiveShowsView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import SwiftUI

struct LiveShowsView: View {
  @Bindable var model: LiveShowsModel

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(model.scheduledShows) { scheduledShow in
          LiveShowTile(scheduledShow: scheduledShow) {
            Task { await model.handleShowTapped(scheduledShow) }
          }
        }
      }
    }
  }
}

// MARK: - Live Show Tile

private struct LiveShowTile: View {
  let scheduledShow: ScheduledShowDisplay
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        // Status badge
        HStack {
          HStack(spacing: 8) {
            if scheduledShow.isLive {
              Image("MicrophoneForNowPlaying")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color(hex: "#FF5252"))
                .frame(width: 10, height: 15)
            }

            Text(scheduledShow.statusText)
              .font(.custom(FontNames.Inter_500_Medium, size: 14))
              .foregroundColor(scheduledShow.isLive ? Color(hex: "#FF5252") : Color(hex: "##FFC107"))
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(scheduledShow.isLive ? Color(red: 0.3, green: 0.1, blue: 0.1) : Color(hex: "#3D3420"))
          .cornerRadius(12)

          Spacer()
        }

        // Show title
        Text(scheduledShow.showTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 22))
          .foregroundColor(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)

        // Date/time
        Text(scheduledShow.timeDisplayString)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.white)
      }
      .padding(16)
      .frame(width: 280, height: 140)
      .background(Color(white: 0.15))
      .cornerRadius(8)
    }
  }
}

// MARK: - Preview

#Preview {
  let now = Date()
  let calendar = Calendar.current

  let mockShows: [ScheduledShowDisplay] = [
    ScheduledShowDisplay(
      id: "1",
      showId: "show1",
      showTitle: "In the Van with the Stelly Band",
      airtime: calendar.date(byAdding: .minute, value: -30, to: now)!,
      endTime: calendar.date(byAdding: .minute, value: 90, to: now)!,
      isLive: true
    ),
    ScheduledShowDisplay(
      id: "2",
      showId: "show2",
      showTitle: "Live with the Paladins",
      airtime: calendar.date(byAdding: .day, value: 11, to: now)!,
      endTime: calendar.date(byAdding: .day, value: 11, to: calendar.date(byAdding: .hour, value: 2, to: now)!)!,
      isLive: false
    ),
    ScheduledShowDisplay(
      id: "3",
      showId: "show3",
      showTitle: "Midnight Jazz Session",
      airtime: calendar.date(byAdding: .day, value: 2, to: now)!,
      endTime: calendar.date(byAdding: .day, value: 2, to: calendar.date(byAdding: .hour, value: 3, to: now)!)!,
      isLive: false
    )
  ]

  return VStack(alignment: .leading, spacing: 12) {
    Text("Live shows")
      .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
      .foregroundColor(.white)

    LiveShowsView(model: LiveShowsModel(scheduledShows: mockShows))
  }
  .padding()
  .background(Color.black)
}
