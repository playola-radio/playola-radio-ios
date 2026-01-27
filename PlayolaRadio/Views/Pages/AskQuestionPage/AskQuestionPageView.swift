//
//  AskQuestionPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct AskQuestionPageView: View {
  @Bindable var model: AskQuestionPageModel

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 24) {
        instructionsHeader

        waveformSection
          .frame(height: 120)
          .padding(.horizontal, 20)

        Spacer()

        recordingStatusSection

        mainButton

        buttonLabel

        Spacer()

        if model.recordingPhase == .review {
          reviewControls
        }
      }
      .padding()
    }
    .navigationTitle("Ask \(model.curatorName)")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      if !model.isUploading {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            model.cancelTapped()
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

  // MARK: - Instructions Header

  @ViewBuilder
  private var instructionsHeader: some View {
    Text(
      "Start with your name and where you're from. Then ask \(model.curatorName) anything you want!"
    )
    .font(.custom(FontNames.Inter_500_Medium, size: 16))
    .foregroundColor(.white)
    .multilineTextAlignment(.center)
    .padding(.vertical, 16)
    .padding(.horizontal, 12)
    .background(Color(hex: "#1A1A1A"))
    .cornerRadius(12)
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

  // MARK: - Recording Status

  @ViewBuilder
  private var recordingStatusSection: some View {
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
      Text(model.displayTime)
        .font(.custom(FontNames.Inter_400_Regular, size: 32))
        .foregroundColor(.white)
        .monospacedDigit()
        .frame(height: 60)
    }
  }

  // MARK: - Main Button

  @ViewBuilder
  private var mainButton: some View {
    switch model.recordingPhase {
    case .idle:
      Button {
        Task { await model.recordTapped() }
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
        Task { await model.stopTapped() }
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
        model.reRecordTapped()
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

  // MARK: - Button Label

  @ViewBuilder
  private var buttonLabel: some View {
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

  // MARK: - Review Controls

  @ViewBuilder
  private var reviewControls: some View {
    VStack(spacing: 16) {
      PlaybackScrubberView(
        currentTime: model.playbackPosition,
        totalTime: model.recordingDuration,
        isPlaying: model.isPlaying,
        onPlayPause: { model.playPauseTapped() },
        onRewind: { model.rewindTapped() },
        onSeek: { model.seekTo($0) }
      )
      .disabled(model.isUploading)
      .opacity(model.isUploading ? 0.5 : 1)

      // Submit button
      Button {
        Task { await model.submitTapped() }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "paperplane.fill")
          Text("Send Question")
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(model.isUploading ? Color.gray : Color.playolaRed)
        .cornerRadius(24)
      }
      .disabled(model.isUploading)

      // Upload status indicator
      if model.uploadPhase != .notStarted {
        HStack(spacing: 12) {
          if model.isUploading {
            ProgressView()
              .tint(.playolaRed)
          } else if case .completed = model.uploadPhase {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
          } else if case .failed = model.uploadPhase {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundColor(.playolaRed)
          }

          Text(model.uploadStatusText)
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .foregroundColor(.white)
        }
        .frame(height: 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 32)
    .animation(.easeInOut(duration: 0.2), value: model.uploadPhase)
  }
}

#Preview {
  NavigationStack {
    AskQuestionPageView(
      model: AskQuestionPageModel(station: .mock)
    )
  }
  .preferredColorScheme(.dark)
}
