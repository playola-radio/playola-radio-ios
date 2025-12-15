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
  @State private var dropTargetSpinId: String?

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

        // Staging Area
        if !model.stagingVoicetracks.isEmpty {
          stagingSection
            .padding(.bottom, 16)
        }

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
                let isDeletable = model.canDeleteSpin(spin)
                VStack(spacing: 0) {
                  // Drop indicator above this row
                  if dropTargetSpinId == spin.id {
                    Rectangle()
                      .fill(Color.playolaRed)
                      .frame(height: 3)
                      .transition(.opacity)
                  }

                  ScheduleRowView(
                    spin: spin,
                    isBeingRescheduled: model.spinIdsBeingRescheduled.contains(spin.id),
                    isDeletable: isDeletable
                  )
                }
                .dropDestination(for: String.self) { items, _ in
                  guard let voicetrackId = items.first else { return false }
                  Task {
                    await model.insertVoicetrack(voicetrackId: voicetrackId, beforeSpinId: spin.id)
                  }
                  return true
                } isTargeted: { isTargeted in
                  withAnimation(.easeInOut(duration: 0.2)) {
                    dropTargetSpinId = isTargeted ? spin.id : nil
                  }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .deleteDisabled(!isDeletable)
                .moveDisabled(!isDeletable)
                .transition(.opacity.combined(with: .move(edge: .top)))
              }
              .onDelete { indexSet in
                guard let index = indexSet.first else { return }
                let spin = model.upcomingSpins[index]
                Task {
                  await model.deleteSpin(spin)
                }
              }
              .onMove { source, destination in
                Task {
                  await model.moveSpins(from: source, to: destination)
                }
              }
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

  // MARK: - Staging Section

  private var stagingSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("READY TO PLACE")
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.playolaGray)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

      ForEach(model.stagingVoicetracks) { voicetrack in
        if voicetrack.isComplete {
          StagingRowView(voicetrack: voicetrack)
            .draggable(voicetrack.id.uuidString) {
              StagingRowView(voicetrack: voicetrack)
                .frame(width: 300)
                .opacity(0.8)
            }
        } else {
          StagingRowView(voicetrack: voicetrack)
        }
      }
    }
    .background(Color(hex: "#1A1A1A"))
  }
}

// MARK: - Staging Row View

struct StagingRowView: View {
  let voicetrack: LocalVoicetrack

  var body: some View {
    HStack(spacing: 12) {
      // Mic icon
      ZStack {
        Circle()
          .fill(Color.playolaRed)
          .frame(width: 40, height: 40)
        Image(systemName: "mic.fill")
          .font(.system(size: 16))
          .foregroundColor(.white)
      }

      // Title
      VStack(alignment: .leading, spacing: 2) {
        Text(voicetrack.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(statusText)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(statusColor)
          .lineLimit(1)
      }

      Spacer()

      // Status indicator
      statusIndicator
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color(hex: "#2A2A2A"))
  }

  private var statusText: String {
    switch voicetrack.status {
    case .converting:
      return "Converting..."
    case .uploading(let progress):
      return "Uploading \(Int(progress * 100))%"
    case .finalizing:
      return "Finalizing..."
    case .completed:
      return "Ready"
    case .failed(let error):
      return error
    }
  }

  private var statusColor: Color {
    switch voicetrack.status {
    case .completed:
      return .green
    case .failed:
      return .playolaRed
    default:
      return .playolaGray
    }
  }

  @ViewBuilder
  private var statusIndicator: some View {
    switch voicetrack.status {
    case .converting, .uploading, .finalizing:
      ProgressView()
        .tint(.white)
        .scaleEffect(0.8)
    case .completed:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(.green)
    case .failed:
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 20))
        .foregroundColor(.playolaRed)
    }
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
  let isBeingRescheduled: Bool
  let isDeletable: Bool

  init(spin: Spin, isBeingRescheduled: Bool = false, isDeletable: Bool = true) {
    self.spin = spin
    self.isBeingRescheduled = isBeingRescheduled
    self.isDeletable = isDeletable
  }

  var isGrouped: Bool { spin.spinGroupId != nil }

  private var timeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter.string(from: spin.airtime).lowercased()
  }

  private var rowBackgroundColor: Color {
    if spin.audioBlock.type == "commercial" {
      return Color.black
    }
    return isDeletable ? Color(hex: "#333333") : Color(hex: "#444444")
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

        // Time or rescheduling indicator
        if isBeingRescheduled {
          ProgressView()
            .tint(.playolaGray)
            .scaleEffect(0.8)
        } else {
          Text("at \(timeString)")
            .font(.custom(FontNames.Inter_400_Regular, size: 11))
            .foregroundColor(.playolaGray)
        }

        // Drag handle
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.playolaGray)
          .padding(.leading, 8)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .background(rowBackgroundColor)
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
