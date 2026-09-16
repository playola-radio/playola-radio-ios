//
//  RecordWithMultiStepPromptView.swift
//  PlayolaRadio
//

import SwiftUI

struct RecordWithMultiStepPromptView: View {
  @Bindable var model: RecordWithMultiStepPromptModel

  var body: some View {
    ZStack {
      Color.playolaSurfaceBase.ignoresSafeArea()
      content
        .rotationEffect(.degrees(model.rotationDegrees))
    }
    .navigationBarHidden(true)
    .toolbar(model.tabBarVisibility, for: .tabBar)
    .playolaAlert($model.presentedAlert)
    .task { await model.viewAppeared() }
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  private var content: some View {
    VStack(spacing: 0) {
      navigationBar
      cueDeck
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var navigationBar: some View {
    ZStack {
      Text(model.navTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.playolaTextPrimary)
      HStack {
        backButton
        Spacer()
      }
      .padding(.leading, 14)
    }
    .frame(height: 64)
  }

  private var backButton: some View {
    Button {
      model.backButtonTapped()
    } label: {
      Image(systemName: "chevron.left")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.playolaTextPrimary)
        .frame(width: 44, height: 44)
        .background(Color.playolaSurfaceControl)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.playolaGlassHairline, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .disabled(!model.backButtonEnabled)
    .opacity(model.backButtonOpacity)
  }

  private var cueDeck: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          introHeader
          recordSections
          reviewSection
          progressSection
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
        .animation(.easeInOut(duration: 0.35), value: model.recordingPhase)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var introHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        Text(model.headerEyebrow)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .tracking(0.8)
          .foregroundColor(.playolaRed)
        Spacer()
        guideBadge
      }
      Text(model.headerTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 27))
        .foregroundColor(.playolaTextPrimary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
      subtitle
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var guideBadge: some View {
    if let badge = model.headerBadge {
      Text(badge)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
        .tracking(0.6)
        .foregroundColor(.playolaTextSecondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.playolaSurfaceSection)
        .clipShape(Capsule())
    }
  }

  @ViewBuilder private var subtitle: some View {
    if let subtitle = model.headerSubtitle {
      Text(subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(5.6)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Record Sections (ready + recording)

  @ViewBuilder private var recordSections: some View {
    if model.showsRecorder {
      Spacer(minLength: 20)
      cuesCard
        .transition(.opacity.combined(with: .move(edge: .top)))
      Spacer(minLength: 20)
      recorderCard
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private var cuesCard: some View {
    VStack(spacing: 0) {
      ForEach(model.steps) { step in
        cueRow(step)
      }
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 16)
    .background(Color.playolaSurfaceSection)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.playolaGlassHairline, lineWidth: 1))
  }

  private func cueRow(_ step: RecordPromptStep) -> some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        ZStack {
          Circle()
            .fill(model.cueNumberBackgroundColor)
            .frame(width: 32, height: 32)
          Text(model.numberText(for: step))
            .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
            .foregroundColor(model.cueNumberForegroundColor)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(step.label)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
            .tracking(0.6)
            .foregroundColor(model.cueLabelColor)
          Text(step.detail)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaTextPrimary)
            .lineSpacing(4.9)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 12)
      Rectangle()
        .fill(model.dividerColor(after: step))
        .frame(height: 1)
    }
  }

  private var recorderCard: some View {
    VStack(spacing: 14) {
      recorderHeader
      audioMeter
      recordButton
    }
    .padding(16)
    .background(Color.playolaSurfaceRaised)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1))
  }

  private var recorderHeader: some View {
    HStack {
      HStack(spacing: 7) {
        Circle()
          .fill(model.statusAccentColor)
          .frame(width: 8, height: 8)
        Text(model.statusLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(0.7)
          .foregroundColor(model.statusAccentColor)
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(model.statusPillColor)
      .clipShape(Capsule())
      Spacer()
      Text(model.trackLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
        .tracking(0.6)
        .foregroundColor(.playolaTextTertiary)
    }
  }

  private var audioMeter: some View {
    VStack(spacing: 7) {
      Text(model.elapsedTime)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
        .foregroundColor(.playolaTextPrimary)
      waveform
    }
    .frame(maxWidth: .infinity)
    .frame(height: 92)
    .background(model.meterBackgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var waveform: some View {
    HStack(spacing: 4) {
      ForEach(model.waveformBars) { bar in
        RoundedRectangle(cornerRadius: 2)
          .fill(bar.color)
          .frame(width: 3, height: bar.height)
      }
    }
    .frame(height: 38)
  }

  private var recordButton: some View {
    Button {
      Task { await model.recordButtonTapped() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: model.recordButtonSystemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.playolaTextPrimary)
        Text(model.recordButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaTextPrimary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(Color.playolaRed)
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Review Section

  @ViewBuilder private var reviewSection: some View {
    if model.showsReview {
      Spacer().frame(height: 20)
      reviewCard
        .transition(.move(edge: .bottom).combined(with: .opacity))
      Spacer(minLength: 0)
    }
  }

  private var reviewCard: some View {
    VStack(spacing: 16) {
      reviewCardHeader
      playbackPreview
      playbackTimeline
      reviewActions
    }
    .padding(16)
    .background(Color.playolaSurfaceRaised)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1))
  }

  private var reviewCardHeader: some View {
    HStack {
      HStack(spacing: 6) {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.playolaRed)
        Text(model.reviewStatusLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(0.7)
          .foregroundColor(.playolaRed)
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(Color.playolaWarmSurface)
      .clipShape(Capsule())
      Spacer()
      Text(model.reviewDurationText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.playolaTextSecondary)
        .monospacedDigit()
    }
  }

  private var playbackPreview: some View {
    HStack(spacing: 14) {
      playButton
      reviewWaveform
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceControl)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var playButton: some View {
    Button {
      Task { await model.playButtonTapped() }
    } label: {
      Image(systemName: model.playButtonSystemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.playolaTextPrimary)
        .frame(width: 48, height: 48)
        .background(Color.playolaRed)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    .buttonStyle(.plain)
  }

  private var reviewWaveform: some View {
    HStack(alignment: .center, spacing: 4) {
      ForEach(model.reviewWaveformBars) { bar in
        RoundedRectangle(cornerRadius: 2)
          .fill(bar.color)
          .frame(width: 4, height: bar.height)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 48)
  }

  private var playbackTimeline: some View {
    HStack(spacing: 12) {
      Text(model.playbackElapsedText)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.playolaTextSecondary)
        .monospacedDigit()
      seekBar
      Text(model.playbackTotalText)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.playolaTextSecondary)
        .monospacedDigit()
    }
  }

  private var seekBar: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.playolaTextSecondary.opacity(0.4))
          .frame(height: 4)
        Capsule()
          .fill(Color.playolaRed)
          .frame(width: geometry.size.width * model.playbackProgress, height: 4)
        Circle()
          .fill(Color.playolaRed)
          .frame(width: 12, height: 12)
          .offset(x: geometry.size.width * model.playbackProgress - 6)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            Task {
              await model.scrubberDragged(
                locationX: value.location.x, trackWidth: geometry.size.width)
            }
          }
      )
    }
    .frame(height: 16)
  }

  private var reviewActions: some View {
    HStack(spacing: 12) {
      Button {
        Task { await model.reRecordButtonTapped() }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: model.reRecordButtonSystemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.playolaTextPrimary)
          Text(model.reRecordButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.playolaTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.playolaSurfaceControl)
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)

      Button {
        Task { await model.useRecordingButtonTapped() }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: model.useRecordingButtonSystemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.playolaTextPrimary)
          Text(model.useRecordingButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.playolaTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.playolaRed)
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Progress Section (saving + uploading)

  @ViewBuilder private var progressSection: some View {
    if model.showsProgress {
      Spacer().frame(height: 20)
      progressCard
        .transition(.move(edge: .bottom).combined(with: .opacity))
      Spacer(minLength: 0)
    }
  }

  private var progressCard: some View {
    VStack(spacing: 20) {
      progressIcon
      Text(model.progressCardTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 22))
        .foregroundColor(.playolaTextPrimary)
      progressBar
      VStack(spacing: 12) {
        ForEach(model.progressSteps) { step in
          progressStepRow(step)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceRaised)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1)
    )
    .geometryGroup()
  }

  private var progressIcon: some View {
    Image(systemName: model.progressIconSystemImage)
      .font(.system(size: 24, weight: .semibold))
      .foregroundColor(.playolaRed)
      .frame(width: 72, height: 72)
      .background(Color.playolaWarmSurface)
      .clipShape(Circle())
  }

  private var progressBar: some View {
    VStack(spacing: 10) {
      HStack {
        Text(model.progressLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.playolaTextPrimary)
        Spacer()
        Text(model.progressValue)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaTextSecondary)
          .monospacedDigit()
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.playolaSurfaceControl)
            .frame(height: 6)
          Capsule()
            .fill(Color.playolaRed)
            .frame(width: geometry.size.width * model.progressFraction, height: 6)
        }
        .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 6)
      .animation(.easeInOut(duration: 0.25), value: model.progressFraction)
    }
  }

  private func progressStepRow(_ step: RecordProgressStep) -> some View {
    HStack(spacing: 12) {
      Image(systemName: step.systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(step.iconColor)
        .frame(width: 32, height: 32)
        .background(step.iconBackgroundColor)
        .clipShape(Circle())
      Text(step.label)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(step.labelColor)
      Spacer(minLength: 0)
    }
  }

}

#Preview {
  NavigationStack {
    RecordWithMultiStepPromptView(model: .askMeAnythingIntro(stationId: "preview"))
  }
  .preferredColorScheme(.dark)
}
