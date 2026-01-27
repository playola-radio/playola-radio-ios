//
//  RecordPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import SwiftUI

struct RecordPageView: View {
  @Bindable var model: RecordPageModel

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        // MARK: - Top: Waveform Area
        waveformSection
          .frame(height: 120)
          .padding(.top, 40)
          .padding(.horizontal, 20)

        // MARK: - Center: Status + Button
        Spacer()

        statusSection

        mainButtonSection
          .padding(.top, 24)

        buttonLabelSection
          .frame(height: 44)
          .padding(.top, 8)

        Spacer()

        // MARK: - Bottom: Playback Controls (review only)
        bottomSection
      }
    }
    .navigationTitle("Audio Recording")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      if model.shouldShowDoneButton {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            model.onDoneTapped()
          }
          .foregroundColor(.white)
        }
      }
    }
    .alert(item: $model.presentedAlert) { $0.alert }
    .task {
      await model.viewAppeared()
    }
  }

  // MARK: - Waveform Section

  @ViewBuilder
  private var waveformSection: some View {
    switch model.recordingPhase {
    case .idle:
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(hex: "#1A1A1A"))
        .overlay(
          Text("Your recording will appear here")
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(Color(hex: "#4A4A4A"))
        )
    case .recording:
      LiveWaveformView(samples: model.waveformSamples)
    case .review:
      WaveformView(samples: model.waveformSamples)
    }
  }

  // MARK: - Status Section

  @ViewBuilder
  private var statusSection: some View {
    switch model.recordingPhase {
    case .idle:
      Color.clear.frame(height: 60)
    case .recording:
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 10, height: 10)
          Text("Recording")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.playolaRed)
        }
        Text(model.displayTime)
          .font(.custom(FontNames.Inter_400_Regular, size: 32))
          .foregroundColor(.white)
          .monospacedDigit()
      }
      .frame(height: 60)
    case .review:
      Color.clear.frame(height: 60)
    }
  }

  // MARK: - Main Button Section

  @ViewBuilder
  private var mainButtonSection: some View {
    switch model.recordingPhase {
    case .idle:
      Button {
        Task { await model.onRecordTapped() }
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 100, height: 100)
          Image(systemName: "mic.fill")
            .font(.system(size: 40))
            .foregroundColor(.white)
        }
      }
    case .recording:
      Button {
        Task { await model.onStopTapped() }
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 100, height: 100)
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.white)
            .frame(width: 32, height: 32)
        }
      }
    case .review:
      Button {
        model.onReRecordTapped()
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 100, height: 100)
          Image(systemName: "mic.fill")
            .font(.system(size: 40))
            .foregroundColor(.white)
        }
      }
    }
  }

  // MARK: - Button Label Section

  @ViewBuilder
  private var buttonLabelSection: some View {
    switch model.recordingPhase {
    case .idle:
      Text("Tap to Record")
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    case .recording:
      Text("Tap to Stop")
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    case .review:
      Text("Try Again")
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    }
  }

  // MARK: - Bottom Section

  @ViewBuilder
  private var bottomSection: some View {
    if model.recordingPhase == .review {
      VStack(spacing: 16) {
        PlaybackScrubberView(
          currentTime: model.playbackPosition,
          totalTime: model.recordingDuration,
          isPlaying: model.isPlaying,
          onPlayPause: { model.onPlayPauseTapped() },
          onRewind: { model.onRewindTapped() },
          onSeek: { model.seekTo($0) }
        )

        HStack(spacing: 12) {
          Button {
            model.onDiscardTapped()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "trash")
              Text("Discard")
            }
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.playolaRed)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
              RoundedRectangle(cornerRadius: 24)
                .stroke(Color.playolaRed, lineWidth: 2)
            )
          }

          Button {
            Task {
              await model.onAcceptRecordingTapped()
            }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "checkmark")
              Text("Use Recording")
            }
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.playolaRed)
            .cornerRadius(24)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }
}

// MARK: - Playback Scrubber View

struct PlaybackScrubberView: View {
  let currentTime: TimeInterval
  let totalTime: TimeInterval
  let isPlaying: Bool
  let onPlayPause: () -> Void
  let onRewind: () -> Void
  let onSeek: (TimeInterval) -> Void

  var progress: Double {
    guard totalTime > 0 else { return 0 }
    return currentTime / totalTime
  }

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onPlayPause) {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 16))
          .foregroundColor(.white)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "#4A4A4A"))
            .frame(height: 4)

          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaRed)
            .frame(width: geometry.size.width * progress, height: 4)

          Circle()
            .fill(Color.playolaRed)
            .frame(width: 14, height: 14)
            .offset(x: geometry.size.width * progress - 7)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let percent = max(0, min(1, value.location.x / geometry.size.width))
              let newTime = percent * totalTime
              onSeek(newTime)
            }
        )
      }
      .frame(height: 14)

      Text(formatTime(currentTime))
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.white)
        .monospacedDigit()

      Button(action: onRewind) {
        Image(systemName: "backward.end.fill")
          .font(.system(size: 14))
          .foregroundColor(.white)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(hex: "#2A2A2A"))
    .cornerRadius(8)
  }

  private func formatTime(_ time: TimeInterval) -> String {
    let totalSeconds = Int(time)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
  }
}

#Preview("Idle") {
  NavigationStack {
    RecordPageView(model: RecordPageModel())
  }
  .preferredColorScheme(.dark)
}

#Preview("Recording") {
  NavigationStack {
    RecordPageView(model: makeRecordingPreviewModel())
  }
  .preferredColorScheme(.dark)
}

#Preview("Review") {
  NavigationStack {
    RecordPageView(model: makeReviewPreviewModel())
  }
  .preferredColorScheme(.dark)
}

@MainActor
private func makeRecordingPreviewModel() -> RecordPageModel {
  let model = RecordPageModel()
  model.recordingPhase = .recording
  model.recordingDuration = 5.3
  model.waveformSamples = (0..<30).map { _ in Float.random(in: 0.2...0.9) }
  return model
}

@MainActor
private func makeReviewPreviewModel() -> RecordPageModel {
  let model = RecordPageModel()
  model.recordingPhase = .review
  model.recordingDuration = 45
  model.playbackPosition = 12
  model.waveformSamples = (0..<100).map { _ in Float.random(in: 0.2...0.9) }
  return model
}
