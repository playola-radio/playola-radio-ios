//
//  BroadcastPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import Dependencies
import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct BroadcastPageView: View {
  @Bindable var model: BroadcastPageModel

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
              model.onAddVoiceTrackTapped()
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
              model.onAddSongTapped()
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

        if model.isLoading {
          Spacer()
          ProgressView()
            .tint(.white)
          Spacer()
        } else {
          TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            // swiftlint:disable:next redundant_discardable_let
            let _ = model.tick()  // Safe: only updates state if nowPlaying actually changed

            // Now Playing (fixed, doesn't scroll)
            if let nowPlaying = model.nowPlaying {
              VStack(spacing: 0) {
                NowPlayingContentView(spin: nowPlaying)
                  .id(nowPlaying.id)
                  .transition(.opacity)

                // Progress bar (doesn't animate with content)
                ProgressView(value: model.nowPlayingProgress)
                  .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))
                  .background(Color(hex: "#5E5F5F"))
              }
            }

            // Schedule List (scrolls)
            List {
              ForEach(model.upcomingSpins, id: \.id) { spin in
                ScheduleRowView(spin: spin)
                  .listRowInsets(EdgeInsets())
                  .listRowSeparator(.hidden)
                  .listRowBackground(Color.clear)
                  .transition(.opacity.combined(with: .move(edge: .top)))
              }
              // TODO: Re-enable reordering when ready
              // .onMove { source, destination in
              //   model.moveSpins(from: source, to: destination)
              // }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
          }
          .animation(.easeInOut(duration: 0.3), value: model.currentNowPlayingId)
        }
      }
    }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .task {
      await model.viewAppeared()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

// MARK: - Now Playing Content View (slides during transition)

struct NowPlayingContentView: View {
  let spin: Spin

  var body: some View {
    HStack(spacing: 12) {
      // Artwork
      ScheduleItemImage(spin: spin)
        .frame(width: 45, height: 45)

      // Title & Artist
      VStack(alignment: .leading, spacing: 2) {
        Text(spin.audioBlock.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(spin.audioBlock.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
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
  }
}

// MARK: - Schedule Row View

struct ScheduleRowView: View {
  let spin: Spin
  var isGrouped: Bool { spin.spinGroupId != nil }

  private var timeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter.string(from: spin.airtime).lowercased()
  }

  var body: some View {
    HStack(spacing: 0) {
      // Group indicator bar
      if isGrouped {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.playolaRed)
          .frame(width: 4)
          .padding(.vertical, 4)
      }

      HStack(spacing: 12) {
        // Artwork / Icon
        ScheduleItemImage(spin: spin)
          .frame(width: 45, height: 45)

        // Title & Artist
        VStack(alignment: .leading, spacing: 2) {
          Text(spin.audioBlock.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
            .lineLimit(1)

          Text(spin.audioBlock.artist)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaGray)
            .lineLimit(1)
        }

        Spacer()

        // VoiceTrack play button
        if spin.audioBlock.type == "voiceTrack" {
          Button {
            // Play preview
          } label: {
            Image(systemName: "play.circle")
              .font(.system(size: 24))
              .foregroundColor(.white)
          }
        }

        // Time
        Text("at \(timeString)")
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
    }
    .background(spin.audioBlock.type == "commercial" ? Color.black : Color(hex: "#333333"))
  }
}

// MARK: - Schedule Item Image

struct ScheduleItemImage: View {
  let spin: Spin

  var body: some View {
    switch spin.audioBlock.type {
    case "song":
      if let imageUrl = spin.audioBlock.imageUrl {
        WebImage(url: imageUrl)
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
    case "voiceTrack":
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.playolaRed.opacity(0.3))
        Image(systemName: "mic.fill")
          .foregroundColor(.playolaRed)
          .font(.system(size: 20))
      }
    case "commercial":
      ZStack {
        Circle()
          .fill(Color(hex: "#2E7D32"))
          .frame(width: 40, height: 40)
        Text("$")
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.white)
      }
    default:
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(hex: "#666666"))
        .overlay(
          Image(systemName: "music.note")
            .foregroundColor(Color(hex: "#999999"))
        )
    }
  }
}

#Preview {
  let now = Date()
  let groupId = "voicetrack-group-1"

  let previewSpins = [
    // Now playing
    Spin.mockWith(
      id: "now-playing",
      airtime: now.addingTimeInterval(-30),
      audioBlock: AudioBlock.mockWith(
        title: "Currently Playing Song",
        artist: "Current Artist",
        endOfMessageMS: 180_000
      )
    ),
    // Upcoming - grouped voicetrack + song
    Spin.mockWith(
      id: "vt-1",
      airtime: now.addingTimeInterval(150),
      audioBlock: AudioBlock.mockWith(
        title: "DJ Intro",
        artist: "Your Voice",
        endOfMessageMS: 15_000,
        type: "voiceTrack"
      ),
      spinGroupId: groupId
    ),
    Spin.mockWith(
      id: "song-after-vt",
      airtime: now.addingTimeInterval(165),
      audioBlock: AudioBlock.mockWith(
        title: "Song After VoiceTrack",
        artist: "Grouped Artist",
        endOfMessageMS: 200_000
      ),
      spinGroupId: groupId
    ),
    // Regular songs
    Spin.mockWith(
      id: "song-2",
      airtime: now.addingTimeInterval(365),
      audioBlock: AudioBlock.mockWith(
        title: "Ungrouped Song",
        artist: "Solo Artist",
        endOfMessageMS: 180_000
      )
    ),
    Spin.mockWith(
      id: "song-3",
      airtime: now.addingTimeInterval(545),
      audioBlock: AudioBlock.mockWith(
        title: "Another Song",
        artist: "Another Artist",
        endOfMessageMS: 210_000
      )
    ),
  ]

  NavigationStack {
    BroadcastPageView(
      model: withDependencies {
        $0.date.now = now
        $0.api.fetchSchedule = { _, _ in previewSpins }
      } operation: {
        BroadcastPageModel(stationId: "preview-station", stationName: "Brian's Station")
      }
    )
  }
  .preferredColorScheme(.dark)
}
