import SDWebImageSwiftUI
import SwiftUI

struct AMALiveContentView: View {
  @Bindable var model: AskMeAnythingLivePageModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(model.navigationTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        Spacer()
        Text(model.listenerCountLabel)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundStyle(Color.playolaTextSecondary)
      }
      .padding(.horizontal, 16)
      .frame(height: 44)
      waitingBanner
        .frame(height: model.waitingHeight)
        .clipped()
        .opacity(model.waitingOpacity)
        .accessibilityHidden(!model.isWaitingToAir)
      nowPlaying
      Color.clear.frame(height: 8)
      queue
      footer
    }
    .foregroundStyle(Color.playolaTextPrimary)
    .background(Color.playolaSurfaceBase)
    .accessibilityAction(.escape) { model.backButtonTapped() }
  }

  private var waitingBanner: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(model.waitingTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
      Text(model.waitingSubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .foregroundStyle(Color.playolaTextSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .frame(height: 64)
    .background(Color.playolaSurfaceSection)
  }

  private var nowPlaying: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        artwork(
          url: model.nowPlayingArtworkURL, color: .playolaSurfaceArtPlaceholder, icon: "music",
          iconOpacity: 0, radius: 0)
        VStack(alignment: .leading, spacing: 2) {
          Text(model.nowPlayingTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .lineLimit(1)
          Text(model.nowPlayingArtist)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundStyle(Color.playolaTextDisabled)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Text(model.liveNowLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
          .foregroundStyle(Color.playolaRed)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.playolaRed, lineWidth: 1))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      progress(model.nowPlayingProgress, color: .playolaRed, track: Color(hex: "#5E5F5F"))
    }
    .background(Color.playolaSurfaceRow)
  }

  private var queue: some View {
    List {
      ForEach(model.liveRows) { row in
        queueRow(row)
          .moveDisabled(!row.isEditable)
          .swipeActions {
            Button(model.deleteRowLabel, role: .destructive) {
              Task { await model.deleteLiveRow(row) }
            }
            .disabled(!row.isEditable)
          }
      }
      .onMove { source, destination in
        Task { await model.moveLiveRows(from: source, to: destination) }
      }
      .listRowInsets(EdgeInsets())
      .listRowSeparator(.hidden)
      .listRowBackground(Color.playolaSurfaceRow)
      addCard
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 0)
    .contentMargins(.all, 0, for: .scrollContent)
    .scrollContentBackground(.hidden)
    .refreshable { await model.viewAppeared() }
  }

  private func queueRow(_ row: AMALiveRowData) -> some View {
    HStack(spacing: 12) {
      artwork(url: row.artworkURL, color: row.artworkColor, icon: row.icon)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Text(row.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundStyle(Color.playolaTextDisabled)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      Text(row.airtime)
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundStyle(Color.playolaTextDisabled)
        .fixedSize()
      Image("AMA-" + row.trailingIcon).resizable().scaledToFit().frame(width: 14, height: 14)
        .foregroundStyle(Color.playolaTextDisabled)
        .padding(.leading, 8)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var addCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 7) {
          Image("AMA-circle-plus").resizable().scaledToFit().frame(width: 18, height: 18)
            .foregroundStyle(Color.playolaRed)
          Text(model.liveAddTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        }
        Text(model.liveAddExplanation)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundStyle(Color.playolaTextSecondary)
      }
      HStack(spacing: 8) {
        action(icon: "mic", label: model.voicetrackActionLabel) { model.voicetrackActionTapped() }
        action(icon: "music-2", label: model.songActionLabel) { model.songActionTapped() }
        action(icon: "messages-square", label: model.qaActionLabel) {
          model.qaActionTapped()
        }
      }
      .padding(.top, 4)
      .frame(height: 92)
      .disabled(!model.canAddLiveAudio)
      ForEach(model.pendingAddIds.prefix(1), id: \.self) { _ in
        Button(model.retryAddLabel) { Task { await model.retryAddingAudio() } }
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .disabled(model.isAddingToShow)
      }
    }
    .padding(16)
    .background(Color.playolaSurfaceSection)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.playolaGlassHairline, lineWidth: 1))
  }

  private func action(icon: String, label: String, tapped: @escaping () -> Void) -> some View {
    Button(action: tapped) {
      VStack(spacing: 8) {
        ZStack(alignment: .bottomTrailing) {
          Circle().fill(Color.playolaRed)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .overlay(Image("AMA-" + icon).resizable().scaledToFit().frame(width: 28, height: 28))
            .frame(width: 64, height: 64)
          Circle().fill(Color.playolaWarmSurface)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .overlay(Image("AMA-plus").resizable().scaledToFit().frame(width: 14, height: 14))
            .frame(width: 22, height: 22)
        }
        Text(label).font(.custom(FontNames.Inter_400_Regular, size: 12))
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
  }

  private var footer: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image("AMA-bell").resizable().scaledToFit().frame(width: 14, height: 14)
        Text(model.waitingFooterLabel).font(.custom(FontNames.Inter_400_Regular, size: 12))
      }
      .foregroundStyle(Color.playolaTextSecondary)
      .frame(height: model.waitingFooterHeight)
      .clipped()
      .opacity(model.waitingOpacity)
      .accessibilityHidden(!model.isWaitingToAir)
      VStack(spacing: 8) {
        HStack {
          Text(model.bufferLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .foregroundStyle(model.bufferTextColor)
          Spacer()
          Text(model.bufferPercentLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundStyle(Color.playolaTextSecondary)
        }
        progress(model.bufferProgress, color: model.bufferColor, track: .playolaSurfaceControl)
        ForEach(model.bufferMessages, id: \.self) { message in
          Text(message)
            .font(model.bufferMessageFont)
            .foregroundStyle(model.bufferMessageColor)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Button {
          Task { await model.endShowButtonTapped() }
        } label: {
          Text(model.endShowButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.playolaSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
              RoundedRectangle(cornerRadius: 12).stroke(Color.playolaGlassHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!model.isEndShowEnabled)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(height: model.liveFooterHeight, alignment: .top)
      .clipped()
      .opacity(model.liveFooterOpacity)
      .allowsHitTesting(!model.isWaitingToAir)
      .accessibilityHidden(model.isWaitingToAir)
    }
  }

  private func artwork(
    url: URL?, color: Color, icon: String, iconOpacity: Double = 1, radius: CGFloat = 4
  ) -> some View {
    RoundedRectangle(cornerRadius: radius).fill(color)
      .overlay(
        Image("AMA-" + icon).resizable().scaledToFit().frame(width: 20, height: 20).opacity(
          iconOpacity)
      )
      .overlay(WebImage(url: url).resizable().scaledToFill())
      .frame(width: 45, height: 45)
      .clipShape(RoundedRectangle(cornerRadius: radius))
  }

  private func progress(_ value: Double, color: Color, track: Color) -> some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        track
        color.frame(width: proxy.size.width * value)
      }
      .clipShape(RoundedRectangle(cornerRadius: 2))
    }
    .frame(height: 4)
  }
}
