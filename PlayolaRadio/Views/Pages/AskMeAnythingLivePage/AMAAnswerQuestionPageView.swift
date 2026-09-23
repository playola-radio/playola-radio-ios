//
//  AMAAnswerQuestionPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct AMAAnswerQuestionPageView: View {
  @Environment(\.displayScale) private var displayScale
  let model: AMAAnswerQuestionPageModel

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
    .navigationBarBackButtonHidden(true)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar(model.tabBarVisibility, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          model.backButtonTapped()
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.textPrimary)
        }
      }
    }
    .playolaAlert(presentedAlertBinding)
    .task { await model.viewAppeared() }
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  private var presentedAlertBinding: Binding<PlayolaAlert?> {
    Binding(get: { model.presentedAlert }, set: { model.presentedAlert = $0 })
  }

  // MARK: - Question Section

  private var questionSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.questionSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.textSecondary)

      VStack(alignment: .leading, spacing: 16) {
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

        Text(model.transcription)
          .font(.custom(FontNames.Inter_400_Regular, size: 15))
          .foregroundColor(.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        questionPlaybackControls
      }
      .padding(16)
      .background(Color.cardSurface)
      .cornerRadius(12)
    }
  }

  private var listenerAvatar: some View {
    ZStack {
      Circle()
        .fill(Color.elevatedSurface)
        .frame(width: 48, height: 48)
        .overlay(
          Text(model.listenerInitials)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
            .foregroundColor(.textSecondary)
        )

      WebImage(
        url: model.listenerProfileImageUrl,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 48, height: 48), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 48, height: 48)
      .clipShape(Circle())
    }
  }

  private var questionPlaybackControls: some View {
    HStack(spacing: 12) {
      Button {
        Task { await model.playQuestionButtonTapped() }
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 40, height: 40)

          Image(systemName: model.questionPlayButtonIcon)
            .font(.system(size: 14))
            .foregroundColor(.white)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
      }

      Text(model.questionPlaybackPositionText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.textPrimary)
        .monospacedDigit()

      questionScrubber

      Text(model.questionDurationText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.textSecondary)
        .monospacedDigit()
    }
  }

  private var questionScrubber: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.elevatedSurface)
          .frame(height: 4)

        Capsule()
          .fill(Color.playolaRed)
          .frame(width: geometry.size.width * model.questionPlaybackProgress, height: 4)

        Circle()
          .fill(Color.playolaRed)
          .frame(width: 14, height: 14)
          .offset(x: geometry.size.width * model.questionPlaybackProgress - 7)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            Task {
              await model.questionScrubberDragged(
                locationX: value.location.x, trackWidth: geometry.size.width)
            }
          }
      )
    }
    .frame(height: 20)
  }

  // MARK: - Response Section

  private var responseSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.responseSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.textSecondary)

      VStack(spacing: 20) {
        waveformArea
          .frame(height: 100)

        Text(model.recordStatusText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.textPrimary)

        recordingTimeRow
          .opacity(model.recordingIndicatorOpacity)

        recordButtonSection
          .opacity(model.recordButtonSectionOpacity)

        reviewControls
          .opacity(model.reviewControlsOpacity)

        submissionStatusView
          .opacity(model.submissionStatusOpacity)
      }
      .padding(16)
      .background(Color.cardSurface)
      .cornerRadius(12)
      .disabled(model.controlsDisabled)
    }
  }

  private var waveformArea: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.elevatedSurface)
        .opacity(model.waveformPlaceholderOpacity)

      LiveWaveformView(samples: model.waveformSamples)
        .opacity(model.recordingIndicatorOpacity)

      WaveformView(samples: model.waveformSamples)
        .opacity(model.reviewControlsOpacity)
    }
  }

  private var recordingTimeRow: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.playolaRed)
        .frame(width: 10, height: 10)

      Spacer()

      Text(model.recordingTimeText)
        .font(.custom(FontNames.Inter_400_Regular, size: 24))
        .foregroundColor(.textPrimary)
        .monospacedDigit()
    }
  }

  private var recordButtonSection: some View {
    VStack(spacing: 8) {
      Button {
        Task { await model.recordButtonTapped() }
      } label: {
        ZStack {
          Circle()
            .fill(Color.playolaRed)
            .frame(width: 80, height: 80)

          Image(systemName: model.recordButtonIcon)
            .font(.system(size: 32))
            .foregroundColor(.textPrimary)
        }
      }

      Text(model.idleHint)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.textSecondary)
        .opacity(model.idlePromptOpacity)

      Text(model.idleRecordLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
        .opacity(model.idlePromptOpacity)

      Text(model.stopRecordingLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
        .opacity(model.recordingIndicatorOpacity)
    }
  }

  private var reviewControls: some View {
    VStack(spacing: 16) {
      answerPlaybackControls

      trailingSongSection

      HStack(spacing: 12) {
        Button {
          Task { await model.recordButtonTapped() }
        } label: {
          Text(model.reRecordLabel)
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
          Task { await model.addToShowButtonTapped() }
        } label: {
          Text(model.addToShowButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.playolaRed)
            .cornerRadius(24)
        }
      }

      Text(model.pairTotalText)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.textSecondary)
    }
  }

  private var answerPlaybackControls: some View {
    HStack(spacing: 12) {
      Button {
        Task { await model.answerPlayPauseButtonTapped() }
      } label: {
        Image(systemName: model.answerPlayButtonIcon)
          .font(.system(size: 16))
          .foregroundColor(.white)
      }

      Text(model.answerPlaybackPositionText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.textPrimary)
        .monospacedDigit()

      answerScrubber

      Text(model.answerDurationText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.textSecondary)
        .monospacedDigit()
    }
  }

  private var answerScrubber: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.elevatedSurface)
          .frame(height: 4)

        Capsule()
          .fill(Color.playolaRed)
          .frame(width: geometry.size.width * model.answerPlaybackProgress, height: 4)

        Circle()
          .fill(Color.playolaRed)
          .frame(width: 14, height: 14)
          .offset(x: geometry.size.width * model.answerPlaybackProgress - 7)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            Task {
              await model.answerScrubberDragged(
                locationX: value.location.x, trackWidth: geometry.size.width)
            }
          }
      )
    }
    .frame(height: 20)
  }

  private var trailingSongSection: some View {
    ZStack {
      Button {
        model.addSongButtonTapped()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "plus.circle")
          Text(model.addSongLabel)
        }
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(.playolaRed)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
      }
      .opacity(model.addSongButtonOpacity)

      trailingSongRow
        .opacity(model.trailingSongRowOpacity)
    }
  }

  private var trailingSongRow: some View {
    HStack(spacing: 12) {
      WebImage(
        url: model.trailingSongArtworkURL,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 40, height: 40), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 40, height: 40)
      .cornerRadius(6)

      VStack(alignment: .leading, spacing: 2) {
        Text(model.trailingSongTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.textPrimary)
          .lineLimit(1)

        Text(model.trailingSongArtist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.textSecondary)
          .lineLimit(1)
      }

      Spacer()

      Button(model.changeSongLabel) {
        model.changeSongButtonTapped()
      }
      .font(.custom(FontNames.Inter_500_Medium, size: 13))
      .foregroundColor(.playolaRed)

      Button(model.removeSongLabel) {
        model.removeSongButtonTapped()
      }
      .font(.custom(FontNames.Inter_500_Medium, size: 13))
      .foregroundColor(.textSecondary)
    }
  }

  private var submissionStatusView: some View {
    VStack(spacing: 8) {
      ProgressView()
        .tint(.playolaRed)
        .opacity(model.submissionSpinnerOpacity)

      Text(model.submissionStatusText)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(.textSecondary)
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    AMAAnswerQuestionPageView(
      model: AMAAnswerQuestionPageModel(
        question: ListenerQuestion.mock,
        airQuestion: { _ in }
      )
    )
  }
  .preferredColorScheme(.dark)
}
