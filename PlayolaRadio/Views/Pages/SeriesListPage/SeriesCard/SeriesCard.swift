//
//  SeriesCard.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct SeriesCard: View {
  @Bindable var model: SeriesCardModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Station Header
      stationHeader
        .padding(.bottom, 16)

      // Show Title
      Text(model.showWithAirings.show.title)
        .font(.custom(FontNames.Inter_700_Bold, size: 21))
        .foregroundColor(.white)
        .padding(.bottom, 12)

      // Schedule Badge
      if let rrule = model.showWithAirings.show.rrule,
        let scheduleText = RRuleFormatter.formatToPlainEnglish(
          rrule: rrule,
          airtime: model.showWithAirings.nextAiring?.airtime ?? Date()
        )
      {
        ScheduleBadge(text: scheduleText)
          .padding(.bottom, 20)
      }

      // Upcoming Episodes Header
      HStack {
        Text("UPCOMING EPISODES")
          .font(.custom(FontNames.Inter_500_Medium, size: 12))
          .tracking(0.06)
          .foregroundColor(Color(hex: "#c7c7c7"))

        Spacer()

        Text("\(model.showWithAirings.upcomingAiringsCount) total")
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#c7c7c7"))
      }
      .padding(.bottom, 8)

      // Episode List
      VStack(spacing: 8) {
        ForEach(model.showWithAirings.airings.prefix(3), id: \.id) { airing in
          EpisodeRow(model: EpisodeRowModel(airing: airing))
        }
      }

      // Remind Me Button (only for not subscribed)
      if model.subscriptionStatus == .notSubscribed {
        Button {
          Task { await model.remindMeTapped() }
        } label: {
          Text("Remind Me")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#ef6962"))
            .cornerRadius(8)
        }
        .padding(.top, 16)
      }
    }
    .padding(20)
    .background(
      LinearGradient(
        colors: [Color(hex: "#1c1a19"), Color(hex: "#2e2a28")],
        startPoint: UnitPoint(x: 0.87, y: 0.02),
        endPoint: UnitPoint(x: 0.13, y: 0.98)
      )
    )
    .cornerRadius(8)
  }

  private var stationHeader: some View {
    HStack(alignment: .top, spacing: 12) {
      // Station Image
      if let imageUrl = model.showWithAirings.station?.imageUrl {
        AsyncImage(url: imageUrl) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Circle()
            .fill(Color.gray.opacity(0.3))
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
      } else {
        Circle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 48, height: 48)
      }

      // Station Info
      VStack(alignment: .leading, spacing: 2) {
        Text(model.showWithAirings.station?.name ?? "Unknown Station")
          .font(.custom(FontNames.Inter_500_Medium, size: 12))
          .tracking(0.06)
          .foregroundColor(Color(hex: "#c7c7c7"))

        Text(model.showWithAirings.station?.curatorName ?? "")
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .foregroundColor(.white)
      }

      Spacer()

      // Subscription Badge
      SubscriptionBadge(status: model.subscriptionStatus)
    }
  }
}

// MARK: - Subscription Status

enum SubscriptionStatus {
  case autoSubscribed
  case subscribed
  case notSubscribed

  var text: String {
    switch self {
    case .autoSubscribed: return "Auto-subscribed"
    case .subscribed: return "Subscribed"
    case .notSubscribed: return "Not subscribed"
    }
  }

  var textColor: Color {
    switch self {
    case .autoSubscribed: return Color(hex: "#4ade80")
    case .subscribed: return Color(hex: "#4ade80")
    case .notSubscribed: return Color(hex: "#bababa")
    }
  }

  var backgroundColor: Color {
    switch self {
    case .autoSubscribed: return Color(hex: "#1a3a1a")
    case .subscribed: return Color(hex: "#1a3a1a")
    case .notSubscribed: return Color(hex: "#3a1a1a")
    }
  }
}

// MARK: - Schedule Badge

struct ScheduleBadge: View {
  let text: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "calendar")
        .font(.system(size: 16))

      Text(text)
        .font(.custom(FontNames.Inter_500_Medium, size: 15))
    }
    .foregroundColor(Color(hex: "#ffc107"))
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#130000").opacity(0.3))
    .cornerRadius(6)
  }
}

// MARK: - Subscription Badge

struct SubscriptionBadge: View {
  let status: SubscriptionStatus

  var body: some View {
    Text(status.text)
      .font(.custom(FontNames.Inter_500_Medium, size: 11))
      .foregroundColor(status.textColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(status.backgroundColor)
      .clipShape(Capsule())
  }
}

// MARK: - Preview

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      SeriesCard(
        model: SeriesCardModel(
          showWithAirings: ShowWithAirings(
            show: .mockWith(
              title: "On the Road with Bri Bagwell",
              rrule: "FREQ=WEEKLY;BYDAY=TU,TH"
            ),
            station: .mockWith(
              name: "Banned Radio",
              curatorName: "Bri Bagwell"
            ),
            airings: [
              .mockWith(
                airtime: Date().addingTimeInterval(86400),
                episode: .mockWith(
                  title: "Live from Austin",
                  createdAt: Date()
                )
              ),
              .mockWith(
                airtime: Date().addingTimeInterval(86400 * 3),
                episode: .mockWith(
                  title: "Nashville Sessions",
                  createdAt: Date().addingTimeInterval(-86400 * 14)
                )
              ),
              .mockWith(
                airtime: Date().addingTimeInterval(86400 * 5),
                episode: .mockWith(
                  title: "Texas Country Vibes",
                  createdAt: Date().addingTimeInterval(-86400 * 7)
                )
              ),
            ],
            now: Date()
          ),
          subscriptionStatus: .autoSubscribed
        )
      )

      SeriesCard(
        model: SeriesCardModel(
          showWithAirings: ShowWithAirings(
            show: .mockWith(
              title: "In the Van with the Stelly Band",
              rrule: "FREQ=WEEKLY;BYDAY=WE"
            ),
            station: .mockWith(
              name: "Moondog Radio",
              curatorName: "Jacob Stelly"
            ),
            airings: [
              .mockWith(
                airtime: Date().addingTimeInterval(86400 * 2),
                episode: .mockWith(
                  title: "Classic Country Hour",
                  createdAt: Date()
                )
              )
            ],
            now: Date()
          ),
          subscriptionStatus: .subscribed
        )
      )

      SeriesCard(
        model: SeriesCardModel(
          showWithAirings: ShowWithAirings(
            show: .mockWith(
              title: "Sunday Morning Acoustics",
              rrule: "FREQ=WEEKLY;BYDAY=SU"
            ),
            station: .mockWith(
              name: "Southern Songs Radio",
              curatorName: "Adam Hood"
            ),
            airings: [
              .mockWith(
                airtime: Date().addingTimeInterval(86400 * 4),
                episode: .mockWith(
                  title: "Unplugged Sessions",
                  createdAt: Date()
                )
              ),
              .mockWith(
                airtime: Date().addingTimeInterval(86400 * 11),
                episode: .mockWith(
                  title: "Songwriter Circle",
                  createdAt: Date().addingTimeInterval(-86400 * 30)
                )
              ),
            ],
            now: Date()
          ),
          subscriptionStatus: .notSubscribed
        )
      )
    }
    .padding(24)
  }
  .background(Color(hex: "#130000"))
}
