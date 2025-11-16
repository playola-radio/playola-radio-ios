//
//  LiveShowsView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import SwiftUI

struct LiveShowsView: View {
  @Bindable var model: ScheduledShowsListModel

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(model.scheduledShows) { scheduledShow in
          LiveShowTile(
            scheduledShow: scheduledShow,
            onTap: {
              Task { await model.handleShowTapped(scheduledShow) }
            },
            onNotifyMeTap: {
              Task { await model.scheduleNotification(for: scheduledShow) }
            }
          )
        }
      }
    }
  }
}

// MARK: - Live Show Tile

private struct LiveShowTile: View {
  let scheduledShow: ScheduledShowDisplay
  let onTap: () -> Void
  let onNotifyMeTap: () -> Void

  var body: some View {
    VStack(alignment: .leading) {
      // Status badge
      HStack {
        if scheduledShow.isLive {
          LiveNowBadge()
        } else {
          UpcomingBadge()
        }
      }
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        // Show title
        Text(scheduledShow.showTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 20))
          .foregroundColor(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        // Show subtitle/description
        Text("In the Van with the Stelly Band")
          .font(.custom(FontNames.Inter_700_Bold, size: 14))
          .foregroundColor(Color(hex: "#F3F0EF"))
          .lineLimit(2)

        // Date/time
        Text(scheduledShow.timeDisplayString)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.bottom, 16)

      // Notify Me button
      Button(action: onNotifyMeTap) {
        HStack(spacing: 10) {
          Image("AlertMe")
            .resizable()
            .renderingMode(.template)
            .foregroundColor(.white.opacity(0.9))
            .frame(width: 22, height: 22)

          Text("Notify Me")
            .font(.custom(FontNames.Inter_500_Medium, size: 18))
            .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        )
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
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
    
    LiveShowsView(model: ScheduledShowsListModel(scheduledShows: mockShows))
  }
  .padding()
  .background(Color.black)
}
