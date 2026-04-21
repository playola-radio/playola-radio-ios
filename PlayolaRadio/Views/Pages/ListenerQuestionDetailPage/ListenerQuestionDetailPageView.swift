//
//  ListenerQuestionDetailPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct ListenerQuestionDetailPageView: View {
  @Bindable var model: ListenerQuestionDetailPageModel

  var body: some View {
    ZStack {
      Color.background
        .edgesIgnoringSafeArea(.all)

      ScrollView {
        VStack(spacing: 24) {
          questionSection
          responseSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
    }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .alert(item: $model.presentedAlert) { $0.alert }
    .task { await model.viewAppeared() }
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  // MARK: - Question Section

  private var questionSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.questionSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.textSecondary)

      VStack(alignment: .leading, spacing: 16) {
        // Listener info
        HStack(spacing: 12) {
          listenerAvatar

          VStack(alignment: .leading, spacing: 2) {
            Text(model.listenerName)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
              .foregroundColor(.textPrimary)

            Text(model.timeAgoText)
              .font(.custom(FontNames.Inter_400_Regular, size: 13))
              .foregroundColor(.textSecondary)
          }

          Spacer()
        }

        // Transcription
        Text(model.transcription)
          .font(.custom(FontNames.Inter_400_Regular, size: 15))
          .foregroundColor(.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        // Play question button
        questionPlaybackControls
      }
      .padding(16)
      .background(Color.cardSurface)
      .cornerRadius(12)
    }
  }

  private var listenerAvatar: some View {
    Group {
      if let imageUrl = model.listenerProfileImageUrl {
        WebImage(url: imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 48, height: 48)
          .clipShape(Circle())
      } else {
        Circle()
          .fill(Color.elevatedSurface)
          .frame(width: 48, height: 48)
          .overlay(
            Text(model.listenerInitials)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
              .foregroundColor(.textSecondary)
          )
      }
    }
  }

  private var questionPlaybackControls: some View {
    HStack(spacing: 12) {
      Button {
        Task { await model.playQuestionButtonTapped() }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: model.questionPlayButtonIcon)
            .font(.system(size: 14))

          Text(
            model.questionPlaybackState.isPlaying
              ? model.questionPlaybackPositionText : model.questionDurationText
          )
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .monospacedDigit()
        }
        .foregroundColor(.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.playolaRed)
        .cornerRadius(20)
      }

      if model.questionPlaybackState.isPlaying {
        ProgressView(value: model.questionPlaybackState.progress)
          .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))
          .background(Color.elevatedSurface)
      }
    }
  }

  // MARK: - Response Section

  private var responseSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.responseSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.textSecondary)

      VStack(spacing: 20) {
        // Waveform area
        waveformSection
          .frame(height: 100)

        // Recording status
        if model.showRecordingIndicator {
          recordingIndicator
        }

        // Record button
        if model.canRecord {
          recordButton
        }

        // Upload status
        if model.showUploadStatus {
          uploadStatusView
        }

        // Answer playback controls (review phase)
        if model.showAnswerPlaybackControls {
          answerPlaybackControls
        }

        // Action buttons (review phase)
        if model.showAnswerActionButtons {
          actionButtons
        }
      }
      .padding(16)
      .background(Color.cardSurface)
      .cornerRadius(12)
    }
  }

  @ViewBuilder
  private var waveformSection: some View {
    if model.showWaveformPlaceholder {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.elevatedSurface)
        .overlay(
          Text(model.waveformPlaceholderText)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.textSecondary)
        )
    } else if model.recordingPhase == .recording {
      LiveWaveformView(samples: model.waveformSamples)
    } else {
      WaveformView(samples: model.waveformSamples)
    }
  }

  private var recordingIndicator: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.playolaRed)
        .frame(width: 10, height: 10)

      Text("Recording")
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(.playolaRed)

      Spacer()

      Text(model.recordingTimeText)
        .font(.custom(FontNames.Inter_400_Regular, size: 24))
        .foregroundColor(.textPrimary)
        .monospacedDigit()
    }
  }

  private var recordButton: some View {
    VStack(spacing: 8) {
      Button {
        Task { await model.recordButtonTapped() }
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 80, height: 80)

          if model.recordingPhase == .recording {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.textPrimary)
              .frame(width: 24, height: 24)
          } else {
            Image(systemName: model.recordButtonIcon)
              .font(.system(size: 32))
              .foregroundColor(.textPrimary)
          }
        }
      }

      Text(model.recordButtonLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
    }
  }

  private var uploadStatusView: some View {
    VStack(spacing: 8) {
      ProgressView(value: model.uploadProgress)
        .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))

      Text(model.uploadStatusText)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(.textSecondary)
    }
  }

  private var answerPlaybackControls: some View {
    PlaybackScrubberView(
      currentTime: model.answerPlaybackState.currentTime,
      totalTime: model.answerPlaybackState.duration,
      isPlaying: model.answerPlaybackState.isPlaying,
      onPlayPause: { Task { await model.answerPlayPauseButtonTapped() } },
      onRewind: { Task { await model.answerRewindButtonTapped() } },
      onSeek: { time in Task { await model.answerScrubberDragged(to: time) } }
    )
  }

  private var actionButtons: some View {
    HStack(spacing: 12) {
      Button {
        model.discardButtonTapped()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "trash")
          Text(model.discardButtonTitle)
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
        Task { await model.uploadButtonTapped() }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.up.circle.fill")
          Text(model.uploadButtonTitle)
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.playolaRed)
        .cornerRadius(24)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ListenerQuestionDetailPageView(
      model: ListenerQuestionDetailPageModel(
        question: ListenerQuestion.mock
      )
    )
  }
  .preferredColorScheme(.dark)
}
