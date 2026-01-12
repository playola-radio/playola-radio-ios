//
//  EpisodeRow.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct EpisodeRow: View {
  let model: EpisodeRowModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Episode Title row with optional Originally Aired badge
      HStack {
        Text(model.airing.episode?.title ?? "Unknown Episode")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.white)

        Spacer()

        if model.hasAiredBefore {
          OriginallyAiredBadge(dateText: model.originallyAiredDateText)
        }
      }

      // Calendar badge and tune in text
      HStack(alignment: .center, spacing: 12) {
        CalendarDateBadge(date: model.airing.airtime)

        Text(model.tuneInText)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color(hex: "#c7c7c7"))

        Spacer()
      }
    }
    .padding(12)
    .background(Color(hex: "#130000").opacity(0.4))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(hex: "#333333"), lineWidth: 1)
    )
    .cornerRadius(8)
  }
}

// MARK: - Calendar Date Badge

struct CalendarDateBadge: View {
  let date: Date

  private var monthString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    return formatter.string(from: date).uppercased()
  }

  private var dayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Red header with month
      Text(monthString)
        .font(.custom(FontNames.Inter_700_Bold, size: 8))
        .foregroundColor(.white)
        .tracking(1.2)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(Color(hex: "#ef6962"))

      // Day number - gradient background with white text
      Text(dayString)
        .font(.custom(FontNames.Inter_700_Bold, size: 13))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          LinearGradient(
            colors: [Color(hex: "#2a2a2a"), Color(hex: "#1a1a1a")],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
    .frame(width: 36, height: 44)
    .cornerRadius(6)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color(hex: "#444444"), lineWidth: 1)
    )
  }
}

// MARK: - Originally Aired Badge

struct OriginallyAiredBadge: View {
  let dateText: String

  var body: some View {
    Text("First Aired \(dateText)")
      .font(.custom(FontNames.Inter_500_Medium, size: 11))
      .foregroundColor(Color(hex: "#bababa"))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color(hex: "#2a2a2a"))
      .cornerRadius(4)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 12) {
    // Upcoming new episode (this week)
    EpisodeRow(
      model: EpisodeRowModel(
        airing: .mockWith(
          airtime: Date().addingTimeInterval(86400),
          episode: .mockWith(title: "Live from Austin")
        )
      )
    )

    // Previously aired episode (next week)
    EpisodeRow(
      model: EpisodeRowModel(
        airing: .mockWith(
          airtime: Date().addingTimeInterval(86400 * 10),
          episode: .mockWith(
            title: "Nashville Sessions",
            createdAt: Date().addingTimeInterval(-86400 * 14)
          )
        )
      )
    )

    // Another episode (beyond next week)
    EpisodeRow(
      model: EpisodeRowModel(
        airing: .mockWith(
          airtime: Date().addingTimeInterval(86400 * 20),
          episode: .mockWith(
            title: "Texas Country Vibes",
            createdAt: Date().addingTimeInterval(-86400 * 7)
          )
        )
      )
    )
  }
  .padding(24)
  .background(Color(hex: "#130000"))
}
