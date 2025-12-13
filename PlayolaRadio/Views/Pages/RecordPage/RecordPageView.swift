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
        // Waveform visualization
        WaveformView(progress: 0.6)
          .frame(height: 150)
          .padding(.top, 60)
          .padding(.horizontal, 20)

        // Time display
        Text("00:02:14")
          .font(.custom(FontNames.Inter_400_Regular, size: 32))
          .foregroundColor(.white)
          .padding(.top, 40)

        // Main action button (Play/Record)
        Button {
          // Play action
        } label: {
          ZStack {
            Circle()
              .fill(Color.playolaRed)
              .frame(width: 100, height: 100)
            Image(systemName: "play.fill")
              .font(.system(size: 40))
              .foregroundColor(.white)
              .offset(x: 4)
          }
        }
        .padding(.top, 30)

        // Re-record label
        Button {
          // Re-record action
        } label: {
          Text("Re-record")
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(.playolaRed)
        }
        .padding(.top, 12)

        Spacer()

        // Playback scrubber
        PlaybackScrubberView(currentTime: 134, totalTime: 134)
          .padding(.horizontal, 20)
          .padding(.bottom, 20)

        // Bottom action buttons
        HStack(spacing: 16) {
          // Discard button
          Button {
            // Discard action
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "trash")
              Text("Discard")
            }
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.playolaRed)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
              RoundedRectangle(cornerRadius: 25)
                .stroke(Color.playolaRed, lineWidth: 2)
            )
          }

          // Accept Recording button
          Button {
            // Accept action
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
              Text("Accept Recording")
            }
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.playolaRed)
            .cornerRadius(25)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
      }
    }
    .navigationTitle("Audio Recording")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          model.onDoneTapped()
        }
        .foregroundColor(.white)
      }
    }
    .task {
      await model.viewAppeared()
    }
  }
}

// MARK: - Waveform View

struct WaveformView: View {
  let progress: Double
  let barCount = 60

  var body: some View {
    GeometryReader { geometry in
      HStack(alignment: .center, spacing: 2) {
        ForEach(0..<barCount, id: \.self) { index in
          let normalizedIndex = Double(index) / Double(barCount)
          let isRecorded = normalizedIndex <= progress

          RoundedRectangle(cornerRadius: 1.5)
            .fill(isRecorded ? Color.playolaRed : Color(hex: "#4A4A4A"))
            .frame(width: 3, height: barHeight(for: index, totalHeight: geometry.size.height))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func barHeight(for index: Int, totalHeight: CGFloat) -> CGFloat {
    // Generate pseudo-random heights that look like audio waveform
    let seed = sin(Double(index) * 0.5) * cos(Double(index) * 0.3)
    let normalizedHeight = abs(seed) * 0.7 + 0.15

    // Add some variation in the middle
    let centerBoost = 1.0 - abs(Double(index - barCount / 2) / Double(barCount / 2)) * 0.5

    return CGFloat(normalizedHeight * centerBoost) * totalHeight
  }
}

// MARK: - Playback Scrubber View

struct PlaybackScrubberView: View {
  let currentTime: Int  // in seconds
  let totalTime: Int  // in seconds

  var progress: Double {
    guard totalTime > 0 else { return 0 }
    return Double(currentTime) / Double(totalTime)
  }

  var body: some View {
    HStack(spacing: 12) {
      // Play button
      Button {
        // Play/pause
      } label: {
        Image(systemName: "play.fill")
          .font(.system(size: 16))
          .foregroundColor(.white)
      }

      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background track
          RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "#4A4A4A"))
            .frame(height: 4)

          // Progress track
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaRed)
            .frame(width: geometry.size.width * progress, height: 4)

          // Thumb
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 14, height: 14)
            .offset(x: geometry.size.width * progress - 7)
        }
      }
      .frame(height: 14)

      // Time label
      Text(formatTime(currentTime))
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.white)
        .monospacedDigit()

      // Rewind button
      Button {
        // Rewind
      } label: {
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

  private func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
  }
}

#Preview {
  NavigationStack {
    RecordPageView(model: RecordPageModel())
  }
  .preferredColorScheme(.dark)
}
