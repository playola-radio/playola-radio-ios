//
//  AMAAnswerQuestionPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct AMAAnswerQuestionPageView: View {
  @Environment(\.displayScale) private var displayScale
  @Bindable var model: AMAAnswerQuestionPageModel

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(spacing: 0) {
          questionSection
          responseSection
          songSection
        }
      }
      footer
    }
    .foregroundStyle(Color.playolaTextPrimary)
    .background(Color.playolaSurfaceBase.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .toolbar(model.tabBarVisibility, for: .tabBar)
    .accessibilityAction(.escape) { model.backButtonTapped() }
    .playolaAlert($model.presentedAlert)
    .task { await model.viewAppeared() }
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  // MARK: - Header

  private var header: some View {
    ZStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))

      HStack {
        Button {
          model.backButtonTapped()
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.playolaTextPrimary)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.playolaSurfaceRaised))
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        Spacer()
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 56)
  }

  // MARK: - Question Section

  private var questionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.questionSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
      questionCard
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }

  private var questionCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        listenerAvatar

        VStack(alignment: .leading, spacing: 2) {
          Text(model.listenerName)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          Text(model.questionMetaText)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundStyle(Color.playolaTextSecondary)
        }

        Spacer()
      }

      Text(model.transcription)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)

      questionAudio
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.playolaSurfaceSection)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var listenerAvatar: some View {
    Circle()
      .fill(Color.playolaSurfaceRaised)
      .frame(width: 44, height: 44)
      .overlay(
        Text(model.listenerInitials)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundStyle(Color.playolaTextSecondary)
      )
      .overlay(
        WebImage(
          url: model.listenerProfileImageUrl,
          context: RemoteArtwork.downsampleContext(
            CGSize(width: 44, height: 44), scale: displayScale)
        )
        .resizable()
        .scaledToFill()
      )
      .clipShape(Circle())
  }

  private var questionAudio: some View {
    VStack(spacing: 0) {
      questionTransport
        .frame(height: model.questionTransportHeight)
        .opacity(model.questionTransportOpacity)
        .allowsHitTesting(model.questionTransportInteractive)
        .clipped()

      questionChip
        .frame(height: model.questionChipHeight)
        .opacity(model.questionChipOpacity)
        .allowsHitTesting(model.questionChipInteractive)
        .clipped()
    }
  }

  private var questionTransport: some View {
    HStack(spacing: 8) {
      Button {
        Task { await model.playQuestionButtonTapped() }
      } label: {
        ZStack {
          Circle().fill(Color.playolaRed).frame(width: 32, height: 32)
          Image(systemName: model.questionPlayButtonIcon)
            .font(.system(size: 14))
            .foregroundStyle(.white)
        }
      }
      .buttonStyle(.plain)

      Text(model.questionPlaybackPositionText)
        .font(.custom(FontNames.Inter_500_Medium, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
        .monospacedDigit()

      questionScrubber

      Text(model.questionDurationText)
        .font(.custom(FontNames.Inter_500_Medium, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
        .monospacedDigit()
    }
    .padding(.horizontal, 10)
    .frame(height: 48)
    .background(Color.playolaSurfaceRaised)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var questionScrubber: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.playolaTextSecondary.opacity(0.45))
          .frame(height: 4)

        Capsule()
          .fill(Color.playolaRed)
          .frame(width: geometry.size.width * model.questionPlaybackProgress, height: 4)

        Circle()
          .fill(Color.playolaRed)
          .frame(width: 12, height: 12)
          .offset(x: geometry.size.width * model.questionPlaybackProgress - 6)
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

  private var questionChip: some View {
    Button {
      Task { await model.playQuestionButtonTapped() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: model.questionPlayButtonIcon)
          .font(.system(size: 14))
          .foregroundStyle(.white)
        Text(model.questionDurationText)
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .monospacedDigit()
      }
      .padding(.horizontal, 14)
      .frame(height: 44)
      .background(Color.playolaSurfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Response Section

  private var responseSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.responseSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
      responseCard
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.top, 16)
  }

  private var responseCard: some View {
    VStack(spacing: 0) {
      idleResponse
        .frame(height: model.idleResponseHeight)
        .opacity(model.idleResponseOpacity)
        .allowsHitTesting(model.idleResponseInteractive)
        .clipped()

      recordingResponse
        .frame(height: model.recordingResponseHeight)
        .opacity(model.recordingResponseOpacity)
        .allowsHitTesting(model.recordingResponseInteractive)
        .clipped()

      reviewResponse
        .frame(height: model.reviewResponseHeight)
        .opacity(model.reviewResponseOpacity)
        .allowsHitTesting(model.reviewResponseInteractive)
        .clipped()
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceSection)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var idleResponse: some View {
    VStack(spacing: 10) {
      VStack(spacing: 8) {
        Text(model.idleInstruction)
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
        Text(model.idleMaxLength)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundStyle(Color.playolaTextSecondary)
      }

      Button {
        Task { await model.recordButtonTapped() }
      } label: {
        ZStack {
          Circle().fill(Color.playolaRed).frame(width: 52, height: 52)
          Image(systemName: "mic.fill")
            .font(.system(size: 24))
            .foregroundStyle(.white)
        }
      }
      .buttonStyle(.plain)

      Text(model.idleRecordLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundStyle(Color.playolaTextSecondary)
    }
    .frame(maxWidth: .infinity)
  }

  private var recordingResponse: some View {
    VStack(spacing: 14) {
      HStack {
        HStack(spacing: 7) {
          Circle().fill(Color.playolaRed).frame(width: 8, height: 8)
          Text(model.recordingLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        }
        Spacer()
        Text(model.recordingTimeText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .monospacedDigit()
      }

      LiveWaveformView(samples: model.waveformSamples)
        .padding(.horizontal, 16)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(Color.playolaSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))

      Button {
        Task { await model.recordButtonTapped() }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "stop.fill")
            .font(.system(size: 16))
            .foregroundStyle(.white)
          Text(model.stopRecordingLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(Color.playolaRed)
        .clipShape(RoundedRectangle(cornerRadius: 22))
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  private var reviewResponse: some View {
    VStack(spacing: 14) {
      HStack {
        Text(model.reviewStatusText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        Spacer()
        Text(model.answerDurationText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .monospacedDigit()
      }

      HStack(spacing: 12) {
        Button {
          Task { await model.answerPlayPauseButtonTapped() }
        } label: {
          ZStack {
            Circle().fill(Color.playolaRed).frame(width: 44, height: 44)
            Image(systemName: model.answerPlayButtonIcon)
              .font(.system(size: 16))
              .foregroundStyle(.white)
          }
        }
        .buttonStyle(.plain)

        answerWaveform
      }
      .padding(.horizontal, 12)
      .frame(height: 72)
      .frame(maxWidth: .infinity)
      .background(Color.playolaSurfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      reRecordButton
        .frame(height: model.reRecordHeight)
        .opacity(model.reRecordOpacity)
        .allowsHitTesting(model.reRecordInteractive)
        .clipped()
    }
    .frame(maxWidth: .infinity)
  }

  private var answerWaveform: some View {
    GeometryReader { geometry in
      WaveformView(samples: model.waveformSamples)
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
    .frame(height: 48)
  }

  private var reRecordButton: some View {
    Button {
      Task { await model.recordButtonTapped() }
    } label: {
      HStack(spacing: 7) {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 16))
        Text(model.reRecordLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
      }
      .foregroundStyle(Color.playolaTextPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .background(Color.playolaSurfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Song Section

  private var songSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.songSectionLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)

      songCard

      changeSongLink
        .frame(height: model.changeSongHeight)
        .opacity(model.songRowOpacity)
        .allowsHitTesting(model.songRowInteractive)
        .clipped()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.top, 18)
  }

  private var songCard: some View {
    VStack(spacing: 0) {
      attachSongRow
        .frame(height: model.attachRowHeight)
        .opacity(model.attachRowOpacity)
        .allowsHitTesting(model.attachInteractive)
        .clipped()

      filledSongRow
        .frame(height: model.songRowHeight)
        .opacity(model.songRowOpacity)
        .allowsHitTesting(model.songRowInteractive)
        .clipped()
    }
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceSection)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var attachSongRow: some View {
    Button {
      model.addSongButtonTapped()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "music.note")
          .font(.system(size: 20))
          .foregroundStyle(Color.playolaRed)
        Text(model.attachSongLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        Spacer()
        Image(systemName: "plus")
          .font(.system(size: 20))
          .foregroundStyle(Color.playolaTextSecondary)
      }
      .padding(.horizontal, 16)
      .frame(height: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var filledSongRow: some View {
    HStack(spacing: 12) {
      Image(systemName: "music.note")
        .font(.system(size: 20))
        .foregroundStyle(Color.playolaRed)

      VStack(alignment: .leading, spacing: 2) {
        Text(model.trailingSongTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .lineLimit(1)
        Text(model.trailingSongSubtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundStyle(Color.playolaTextSecondary)
          .lineLimit(1)
      }

      Spacer()

      Button {
        model.removeSongButtonTapped()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 20))
          .foregroundStyle(Color.playolaTextSecondary)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.leading, 16)
    .frame(height: 76)
  }

  private var changeSongLink: some View {
    Button {
      model.changeSongButtonTapped()
    } label: {
      Text(model.changeSongLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
        .foregroundStyle(Color.playolaRed)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: 8) {
      Text(model.submissionStatusText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundStyle(Color.playolaTextSecondary)
        .opacity(model.submissionStatusOpacity)

      Text(model.pairingText)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
        .frame(height: model.pairingLineHeight)
        .opacity(model.pairingLineOpacity)
        .clipped()

      Text(model.playlistBehaviorText)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
        .multilineTextAlignment(.center)

      Button {
        Task { await model.addToShowButtonTapped() }
      } label: {
        Text(model.addToShowButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundStyle(model.addToShowForeground)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(model.addToShowBackground)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .disabled(!model.addToShowEnabled)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 28)
    .background(Color.playolaSurfaceBase)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    AMAAnswerQuestionPageView(
      model: AMAAnswerQuestionPageModel(
        question: ListenerQuestion.mock,
        addToShow: { _ in }
      )
    )
  }
  .preferredColorScheme(.dark)
}
