//
//  RecordIntroPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct RecordIntroPageView: View {
  @Bindable var model: RecordIntroPageModel

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        customNavigationBar
          .padding(.horizontal, 20)

        songInfoHeader
          .padding(.top, 16)
          .padding(.horizontal, 20)

        instructionsSection
          .padding(.top, 16)
          .padding(.horizontal, 20)

        waveformSection
          .frame(height: 120)
          .padding(.top, 20)
          .padding(.horizontal, 20)

        Spacer()

        statusSection

        mainButtonSection
          .padding(.top, 24)

        buttonLabelSection
          .frame(height: 44)
          .padding(.top, 8)

        Spacer()

        bottomSection
      }
    }
    .rotationEffect(.degrees(180))
    .background(Color.black.ignoresSafeArea())
    .navigationBarHidden(true)
    .playolaAlert($model.presentedAlert)
    .task {
      await model.viewAppeared()
    }
  }

  // MARK: - Custom Navigation Bar

  private var customNavigationBar: some View {
    ZStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.white)

      HStack {
        Spacer()
        if model.shouldShowDoneButton {
          Button {
            model.onDoneTapped()
          } label: {
            Text(model.doneButtonLabel)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Color(hex: "#333333"))
              .clipShape(Capsule())
          }
        }
      }
    }
    .frame(height: 44)
  }

  // MARK: - Song Info Header

  private var songInfoHeader: some View {
    HStack(spacing: 12) {
      if let imageUrl = model.songImageUrl {
        WebImage(url: imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 56, height: 56)
          .cornerRadius(6)
          .clipped()
      } else {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color(hex: "#666666"))
          .frame(width: 56, height: 56)
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
          )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(model.songTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(model.songArtist)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(12)
    .background(Color(hex: "#1A1A1A"))
    .cornerRadius(10)
  }

  // MARK: - Instructions Section

  private var instructionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(model.instructionItems.enumerated()), id: \.offset) { index, instruction in
        HStack(alignment: .top, spacing: 8) {
          Text("\(index + 1).")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.playolaGray)
            .frame(width: 20, alignment: .trailing)

          Text(instruction)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
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
          Text(model.idleWaveformPlaceholder)
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
          Text(model.recordingStatusLabel)
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
        Task { await model.onReRecordTapped() }
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
      Text(model.tapToRecordLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    case .recording:
      Text(model.tapToStopLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    case .review:
      Text(model.tryAgainLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
    }
  }

  // MARK: - Bottom Section

  @ViewBuilder
  private var bottomSection: some View {
    if model.recordingPhase == .review {
      VStack(spacing: 16) {
        if model.shouldShowUploadStatus {
          uploadSection
        } else {
          reviewControls
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  private var reviewControls: some View {
    VStack(spacing: 16) {
      PlaybackScrubberView(
        currentTime: model.playbackPosition,
        totalTime: model.recordingDuration,
        isPlaying: model.isPlaying,
        onPlayPause: { Task { await model.onPlayPauseTapped() } },
        onRewind: { Task { await model.onRewindTapped() } },
        onSeek: { time in Task { await model.seekTo(time) } }
      )

      HStack(spacing: 12) {
        Button {
          model.onDiscardTapped()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "trash")
            Text(model.discardButtonLabel)
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
          Task { await model.onAcceptRecordingTapped() }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "checkmark")
            Text(model.useRecordingButtonLabel)
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
  }

  private var uploadSection: some View {
    VStack(spacing: 16) {
      if let progress = model.uploadProgress {
        ProgressView(value: progress)
          .tint(.playolaRed)
      } else if model.isUploading {
        ProgressView()
          .tint(.playolaRed)
      }

      if model.shouldShowRetryButton {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 40))
          .foregroundColor(.playolaRed)
      } else if case .completed = model.uploadStatus {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 40))
          .foregroundColor(.success)
      }

      Text(model.uploadStatusLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
        .foregroundColor(.white)

      if model.shouldShowRetryButton {
        HStack(spacing: 12) {
          Button {
            Task { await model.confirmDiscard() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "trash")
              Text(model.discardButtonLabel)
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
            Task { await model.onRetryTapped() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "arrow.clockwise")
              Text(model.retryButtonLabel)
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
    }
  }
}

#Preview("Idle") {
  NavigationStack {
    RecordIntroPageView(
      model: RecordIntroPageModel(
        songTitle: "Bohemian Rhapsody",
        songArtist: "Queen",
        songImageUrl: nil,
        stationId: "preview-station",
        audioBlockId: nil
      )
    )
  }
  .preferredColorScheme(.dark)
}
