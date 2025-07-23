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

@MainActor
@Observable
class ListeningTimeModel {
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  var totalListeningTime: Int = 0

  var hourString: String {
    let totalSeconds = totalListeningTime / 1000
    let hours = totalSeconds / 3600
    return String(format: "%02d", hours)
  }

  var minString: String {
    let totalSeconds = totalListeningTime / 1000
    let minutes = (totalSeconds % 3600) / 60
    return String(format: "%02d", minutes)
  }

  var secString: String {
    let totalSeconds = totalListeningTime / 1000
    let seconds = totalSeconds % 60
    return String(format: "%02d", seconds)
  }

  private var refreshTask: Task<Void, Never>?

  func viewAppeared() {
    refreshTask?.cancel()
    refreshTask = Task {
      while !Task.isCancelled {
        if let ms = listeningTracker?.totalListenTimeMS {
          print("Updating listening time to", ms)
          totalListeningTime = ms
        } else {
          print("Tracker missing or zero")
          totalListeningTime = 0
        }

        try? await clock.sleep(for: .seconds(1))
      }
    }
  }

  func viewDisappeared() {
    refreshTask?.cancel()
    refreshTask = nil
  }
}

struct ListeningTimeTile: View {
  @Bindable var model: ListeningTimeModel

  let onRedeemRewards: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "radio")
          .foregroundColor(.white)

        Text("Listening Time")
          .font(.custom(FontNames.SpaceGrotesk_500_Medium, size: 16))
          .foregroundColor(.white)

        Spacer()
      }

      Text("\(model.hourString)h \(model.minString)m \(model.secString)s")
        .font(.custom(FontNames.Inter_700_Bold, size: 32))
        .foregroundColor(.white)

      Button(action: onRedeemRewards) {
        HStack {
          Spacer()
          Text("Redeem Your Rewards!")
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
    .padding(20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
    .onAppear { model.viewAppeared() }
    .onDisappear { model.viewDisappeared() }
  }
}

// MARK: - Preview
#Preview {
  ListeningTimeTile(model: ListeningTimeModel())
    .padding()
    .background(Color.black)
}
