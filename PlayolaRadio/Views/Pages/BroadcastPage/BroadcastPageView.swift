//
//  BroadcastPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import SwiftUI

struct BroadcastPageView: View {
  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        // Action Buttons
        HStack {
          Spacer()

          VStack(spacing: 8) {
            Button {
              // Add VoiceTrack action
            } label: {
              ZStack {
                Circle()
                  .fill(Color.playolaRed)
                  .frame(width: 100, height: 100)
                  .overlay(
                    Circle()
                      .stroke(Color.white, lineWidth: 4)
                  )
                Image("BroadcastMicIcon")
                  .resizable()
                  .renderingMode(.template)
                  .foregroundColor(.white)
                  .frame(width: 40, height: 50)
              }
            }
            Text("Add a VoiceTrack")
              .font(.custom(FontNames.Inter_400_Regular, size: 12))
              .foregroundColor(.white)
          }

          Spacer()

          VStack(spacing: 8) {
            Button {
              // Add Song action
            } label: {
              ZStack {
                Circle()
                  .fill(Color.playolaRed)
                  .frame(width: 100, height: 100)
                  .overlay(
                    Circle()
                      .stroke(Color.white, lineWidth: 4)
                  )
                Image("BroadcastAddSongIcon")
                  .resizable()
                  .renderingMode(.template)
                  .foregroundColor(.white)
                  .frame(width: 50, height: 50)
              }
            }
            Text("Add a Song")
              .font(.custom(FontNames.Inter_400_Regular, size: 12))
              .foregroundColor(.white)
          }

          Spacer()
        }
        .padding(.top, 20)
        .padding(.bottom, 20)

        // Now Playing (fixed, doesn't scroll)
        if let nowPlaying = MockScheduleItem.mockItems.first(where: { $0.isLiveNow }) {
          NowPlayingRowView(item: nowPlaying)
        }

        // Schedule List (scrolls)
        List {
          ForEach(MockScheduleItem.mockItems.filter { !$0.isLiveNow }) { item in
            ScheduleRowView(item: item)
              .listRowInsets(EdgeInsets())
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
          }
          .onMove { _, _ in }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
      }
    }
    .navigationTitle("Broadcast")
    .navigationBarTitleDisplayMode(.inline)
    .foregroundStyle(.white)
  }
}

// MARK: - Now Playing Row View (Fixed at top)

struct NowPlayingRowView: View {
  let item: MockScheduleItem

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        // Artwork
        ScheduleItemImage(item: item)
          .frame(width: 45, height: 45)

        // Title & Artist
        VStack(alignment: .leading, spacing: 2) {
          Text(item.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
            .lineLimit(1)

          if let artist = item.artist {
            Text(artist)
              .font(.custom(FontNames.Inter_400_Regular, size: 12))
              .foregroundColor(.playolaGray)
              .lineLimit(1)
          }
        }

        Spacer()

        // Live Now badge
        Text("LIVE NOW")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
          .foregroundColor(.playolaRed)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(Color.playolaRed, lineWidth: 1)
          )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(hex: "#333333"))

      // Progress bar
      ProgressView(value: 0.3)
        .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))
        .background(Color(hex: "#5E5F5F"))
    }
  }
}

// MARK: - Schedule Row View

struct ScheduleRowView: View {
  let item: MockScheduleItem

  var body: some View {
    HStack(spacing: 12) {
      // Artwork / Icon
      ScheduleItemImage(item: item)
        .frame(width: 45, height: 45)

      // Title & Artist
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        if let artist = item.artist {
          Text(artist)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaGray)
            .lineLimit(1)
        }
      }

      Spacer()

      // VoiceTrack play button
      if item.type == .voiceTrack {
        Button {
          // Play preview
        } label: {
          Image(systemName: "play.circle")
            .font(.system(size: 24))
            .foregroundColor(.white)
        }
      }

      // Time
      Text("at \(item.timeString)")
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundColor(.playolaGray)

      // Drag handle
      Image(systemName: "line.3.horizontal")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.playolaGray)
        .padding(.leading, 8)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(item.type == .commercial ? Color.black : Color(hex: "#333333"))
  }
}

// MARK: - Schedule Item Image

struct ScheduleItemImage: View {
  let item: MockScheduleItem

  var body: some View {
    switch item.type {
    case .song:
      if let imageName = item.imageName {
        Image(imageName)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 45, height: 45)
          .clipped()
      } else {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(hex: "#666666"))
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
          )
      }
    case .voiceTrack:
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.playolaRed.opacity(0.3))
        Image(systemName: "mic.fill")
          .foregroundColor(.playolaRed)
          .font(.system(size: 20))
      }
    case .commercial:
      ZStack {
        Circle()
          .fill(Color(hex: "#2E7D32"))
          .frame(width: 40, height: 40)
        Text("$")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.white)
      }
    }
  }
}

// MARK: - Mock Data

enum ScheduleItemType {
  case song
  case voiceTrack
  case commercial
}

struct MockScheduleItem: Identifiable {
  let id = UUID()
  let type: ScheduleItemType
  let title: String
  let artist: String?
  let timeString: String
  let isLiveNow: Bool
  let imageName: String?

  static let mockItems: [MockScheduleItem] = [
    MockScheduleItem(
      type: .song, title: "Madison", artist: "Orla Gartland",
      timeString: "2:34:00pm", isLiveNow: true, imageName: nil),
    MockScheduleItem(
      type: .song, title: "Shiny Bruise", artist: "The Damnwells",
      timeString: "2:37:45pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "More Hearts Than Mine", artist: "Ingrid Andress",
      timeString: "2:40:38pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "Big Sky", artist: "Rachel Loy",
      timeString: "2:45:19pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .voiceTrack, title: "VoiceTrack", artist: nil,
      timeString: "2:49:54pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "A Fine Romance", artist: "Ella Fitzgerald",
      timeString: "2:50:00pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "Copa Vacia", artist: "Shakira",
      timeString: "2:53:04pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "All Of Me", artist: "Ella Fitzgerald",
      timeString: "2:57:04pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .commercial, title: "Commercial", artist: nil,
      timeString: "3:00:14pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "Big Sky", artist: "Rachel Loy",
      timeString: "3:03:13pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "BESO", artist: "ROSALIA",
      timeString: "3:07:54pm", isLiveNow: false, imageName: nil),
    MockScheduleItem(
      type: .song, title: "Big Sky", artist: "Rachel Loy",
      timeString: "3:12:35pm", isLiveNow: false, imageName: nil),
  ]
}

#Preview {
  NavigationStack {
    BroadcastPageView()
  }
  .preferredColorScheme(.dark)
}
