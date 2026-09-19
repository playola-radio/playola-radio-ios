//
//  AskMeAnythingLivePageView.swift
//  PlayolaRadio
//

import SwiftUI

struct AskMeAnythingLivePageView: View {
  @Bindable var model: AskMeAnythingLivePageModel

  var body: some View {
    VStack(spacing: 0) {
      header
      ZStack {
        setupContent
          .opacity(model.setupLayerOpacity)
          .allowsHitTesting(model.setupLayerInteractive)
          .accessibilityHidden(model.setupLayerAccessibilityHidden)
        activeContent
          .opacity(model.activeLayerOpacity)
          .allowsHitTesting(model.activeLayerInteractive)
          .accessibilityHidden(model.activeLayerAccessibilityHidden)
        ProgressView()
          .tint(.white)
          .opacity(model.loadingOpacity)
          .accessibilityHidden(model.loadingAccessibilityHidden)
      }
    }
    .background(Color.playolaSurfaceBase)
    .navigationBarHidden(true)
    .task { await model.viewAppeared() }
    .onChange(of: model.broadcast.currentNowPlayingId) { model.schedulePlaybackChanged() }
    .playolaAlert($model.presentedAlert)
  }

  private var setupContent: some View {
    ScrollView {
      ZStack(alignment: .top) {
        introPromptContent
          .padding(.horizontal, 16)
          .opacity(model.introPromptOpacity)
          .allowsHitTesting(model.introPromptInteractive)
          .accessibilityHidden(model.introPromptAccessibilityHidden)
        openingPlaylistContent
          .opacity(model.openingPlaylistOpacity)
          .allowsHitTesting(model.openingPlaylistInteractive)
          .accessibilityHidden(model.openingPlaylistAccessibilityHidden)
      }
      .padding(.top, 20)
    }
    .safeAreaInset(edge: .bottom) { bottomBar }
  }

  private var activeContent: some View {
    BroadcastContentView(model: model.broadcast)
      .safeAreaInset(edge: .bottom) {
        Button {
          Task { await model.endShowButtonTapped() }
        } label: {
          Text(model.endShowButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.playolaRed)
            .cornerRadius(12)
        }
        .disabled(!model.isEndShowEnabled)
        .padding(16)
        .background(Color.playolaSurfaceBase)
      }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Button {
        model.backButtonTapped()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.playolaTextPrimary)
      }
      .buttonStyle(.plain)
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.playolaTextPrimary)
      Spacer()
      Text(model.setupLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundColor(.playolaTextSecondary)
    }
    .frame(height: 44)
    .padding(.horizontal, 16)
  }

  // MARK: - Record-intro state (01)

  private var introPromptContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      introCard
      Text(model.preparationReassurance)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(4.8)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.top, 16)
    }
  }

  private var introCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      ZStack {
        Circle()
          .fill(Color.playolaWarmSurface)
          .frame(width: 56, height: 56)
        Image(systemName: "mic.fill")
          .font(.system(size: 26))
          .foregroundColor(.playolaRed)
      }
      Text(model.introTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 21))
        .foregroundColor(.playolaTextPrimary)
      Text(model.introBody)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(6.75)
        .fixedSize(horizontal: false, vertical: true)
      recordIntroButton
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.playolaSurfaceSection)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1)
    )
  }

  private var recordIntroButton: some View {
    Button {
      model.recordIntroButtonTapped()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "mic.fill")
          .font(.system(size: 18))
        Text(model.recordIntroButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
      }
      .foregroundColor(.playolaTextPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(Color.playolaRed)
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Build-your-opening state (01b)

  private var openingPlaylistContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      openingPlaylistHeading
        .padding(.horizontal, 16)
      VStack(spacing: 0) {
        ForEach(model.openingRows) { row in
          AMAOpeningRowView(data: row)
        }
      }
      addToShowCard
        .padding(.horizontal, 16)
    }
  }

  private var openingPlaylistHeading: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(model.openingPlaylistTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 21))
        .foregroundColor(.playolaTextPrimary)
      Text(model.openingPlaylistSubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
    }
  }

  private var addToShowCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 7) {
        Image(systemName: "plus.circle")
          .font(.system(size: 18))
          .foregroundColor(.playolaRed)
        Text(model.addSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 19))
          .foregroundColor(.playolaTextPrimary)
      }
      Text(model.addSectionExplanation)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(4.8)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 12) {
        addAction(icon: "mic", label: model.voicetrackActionLabel) {
          model.voicetrackActionTapped()
        }
        addAction(icon: "music.note", label: model.songActionLabel) {
          model.songActionTapped()
        }
        addAction(icon: "bubble.left.and.bubble.right", label: model.qaActionLabel) {
          model.qaActionTapped()
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.playolaSurfaceSection)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1)
    )
  }

  private func addAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 10) {
        ZStack(alignment: .bottomTrailing) {
          ZStack {
            Circle()
              .fill(Color.playolaRed)
              .frame(width: 64, height: 64)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 2))
            Image(systemName: icon)
              .font(.system(size: 24))
              .foregroundColor(.playolaTextPrimary)
          }
          ZStack {
            Circle()
              .fill(Color.playolaWarmSurface)
              .frame(width: 22, height: 22)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 1.5))
            Image(systemName: "plus")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.playolaTextPrimary)
          }
        }
        Text(label)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaTextPrimary)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Bottom bar

  private var bottomBar: some View {
    VStack(spacing: 8) {
      Button(model.scheduleRetryTitle) {
        Task { await model.viewAppeared() }
      }
      .opacity(model.scheduleRetryOpacity)
      .allowsHitTesting(model.scheduleRetryVisible)
      .accessibilityHidden(model.scheduleRetryAccessibilityHidden)
      HStack {
        Text(model.preparedAudioLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
          .foregroundColor(.playolaTextPrimary)
        Spacer()
        Text(model.readinessHint)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(model.readinessHintColor)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaSurfaceControl)
          RoundedRectangle(cornerRadius: 2)
            .fill(model.readyProgressColor)
            .frame(width: proxy.size.width * model.readyProgress)
        }
      }
      .frame(height: 4)

      startShowButton
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.playolaSurfaceBase)
  }

  private var startShowButton: some View {
    Button {
      Task { await model.startShowButtonTapped() }
    } label: {
      Text(model.startShowButtonTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(model.startShowButtonTitleColor)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(model.startShowButtonBackgroundColor)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(model.startShowButtonBorderColor, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .disabled(!model.isStartShowEnabled)
  }
}

#Preview("Record intro") {
  NavigationStack {
    AskMeAnythingLivePageView(model: AskMeAnythingLivePageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}

#Preview("Build your opening") {
  let model = AskMeAnythingLivePageModel(stationId: "station-preview")
  model.openingItems.append(
    AMAOpeningItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
      content: .intro(.mockWith(id: "intro", durationMS: 30_000))))
  return NavigationStack {
    AskMeAnythingLivePageView(model: model)
  }
  .preferredColorScheme(.dark)
}
