//
//  AskMeAnythingLivePageView.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import SwiftUI

struct AskMeAnythingLivePageView: View {
  @Bindable var model: AskMeAnythingLivePageModel

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      content
    }
    .task { await model.startMonitoring() }
    .playolaAlert($model.presentedAlert)
  }

  private var content: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          waitingBanner
            .opacity(model.waitingBannerOpacity)
          runningMonitor
            .opacity(model.runningMonitorOpacity)
          unavailableBanner
            .opacity(model.doneButtonOpacity)
          addToShowCard
        }
        .padding(16)
      }
      footer
    }
    .background(Color.playolaSurfaceBase)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 8) {
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.playolaTextPrimary)
      Spacer()
      Text(model.listenerCountLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.playolaTextSecondary)
    }
    .frame(height: 44)
    .padding(.horizontal, 16)
  }

  // MARK: - Waiting banner

  private var waitingBanner: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.waitingCountdownLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 19))
        .foregroundColor(.playolaTextPrimary)
      Text(model.waitingSubtitleLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
      Text(model.waitingFooterLabel)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundColor(.playolaTextTertiary)
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

  // MARK: - Running monitor (now playing + queue)

  private var runningMonitor: some View {
    VStack(spacing: 12) {
      nowPlayingCard
      queueList
    }
  }

  private var nowPlayingCard: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(model.nowPlayingTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.playolaTextPrimary)
            .lineLimit(1)
          Text(model.nowPlayingArtist)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaTextSecondary)
            .lineLimit(1)
        }
        Spacer()
        Text(model.liveNowLabel)
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
      .background(Color.playolaSurfaceRaised)

      ProgressView(value: model.nowPlayingProgress)
        .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))
        .background(Color.playolaProgressTrack)
    }
    .cornerRadius(12)
  }

  private var queueList: some View {
    VStack(spacing: 0) {
      ForEach(model.upcomingSpins, id: \.id) { spin in
        queueRow(for: spin)
      }
    }
    .cornerRadius(12)
  }

  private func queueRow(for spin: Spin) -> some View {
    HStack(spacing: 12) {
      ScheduleItemImage(spin: spin)
        .frame(width: 45, height: 45)
      VStack(alignment: .leading, spacing: 2) {
        Text(spin.audioBlock.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaTextPrimary)
          .lineLimit(1)
        Text(spin.audioBlock.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
          .lineLimit(1)
      }
      Spacer()
      Image(systemName: "pin.fill")
        .font(.system(size: 12))
        .foregroundColor(.playolaTextTertiary)
        .opacity(model.pinOpacity(for: spin))
      Text(model.airtimeLabel(for: spin.airtime))
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundColor(.playolaTextSecondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.playolaSurfaceRow)
  }

  // MARK: - Unavailable banner (ended / unavailable)

  private var unavailableBanner: some View {
    Text(model.unavailableMessage)
      .font(.custom(FontNames.Inter_400_Regular, size: 14))
      .foregroundColor(.playolaTextSecondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(20)
      .background(Color.playolaSurfaceSection)
      .cornerRadius(16)
  }

  // MARK: - Add to Show (disabled; PR2 wires this)

  private var addToShowCard: some View {
    Button {
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "plus.circle")
          .font(.system(size: 18))
        Text(model.addToShowTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
      }
      .foregroundColor(.playolaTextPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(Color.playolaSurfaceSection)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.playolaGlassHairline, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!model.isAddToShowEnabled)
  }

  // MARK: - Footer (preparedness meter + End Show / Done)

  private var footer: some View {
    VStack(spacing: 12) {
      VStack(spacing: 6) {
        HStack {
          Text(model.bufferedMeterLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .foregroundColor(.playolaTextPrimary)
          Spacer()
          Text(model.bufferedPercentLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaTextSecondary)
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color.playolaSurfaceControl)
            RoundedRectangle(cornerRadius: 2)
              .fill(Color.playolaSuccessGreen)
              .frame(width: proxy.size.width * model.bufferedMeterFraction)
          }
        }
        .frame(height: 4)
      }

      ZStack {
        endShowButton
          .opacity(model.endShowButtonOpacity)
          .allowsHitTesting(model.endShowButtonOpacity == 1)
        doneButton
          .opacity(model.doneButtonOpacity)
          .allowsHitTesting(model.doneButtonOpacity == 1)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.playolaSurfaceBase)
  }

  private var endShowButton: some View {
    Button {
      model.endShowButtonTapped()
    } label: {
      Text(model.endShowButtonDisplayTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.playolaTextPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.playolaRed)
        .cornerRadius(12)
    }
    .buttonStyle(.plain)
    .disabled(!model.isEndShowEnabled)
  }

  private var doneButton: some View {
    Button {
      model.doneButtonTapped()
    } label: {
      Text(model.doneButtonTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.playolaTextPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.playolaRed)
        .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let now = Date(timeIntervalSince1970: 1_000_000)
  let previewSpins = [
    Spin.mockWith(
      id: "now-playing",
      airtime: now.addingTimeInterval(-30),
      audioBlock: .mockWith(title: "Q&A Question 1", artist: "Listener", endOfMessageMS: 120_000),
      liveShowId: "show-preview"
    ),
    Spin.mockWith(
      id: "up-next",
      airtime: now.addingTimeInterval(90),
      audioBlock: .mockWith(title: "Q&A Question 2", artist: "Listener", endOfMessageMS: 90_000),
      liveShowId: "show-preview"
    ),
  ]

  return NavigationStack {
    AskMeAnythingLivePageView(
      model: withDependencies {
        $0.date.now = now
        $0.api.fetchSchedule = { _, _ in previewSpins }
      } operation: {
        AskMeAnythingLivePageModel(
          stationId: "preview-station", liveShowId: "show-preview", scheduledStartsAt: now)
      }
    )
  }
  .preferredColorScheme(.dark)
}
