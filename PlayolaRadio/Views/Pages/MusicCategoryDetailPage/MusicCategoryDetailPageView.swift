//
//  MusicCategoryDetailPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct MusicCategoryDetailPageView: View {
  @Bindable var model: MusicCategoryDetailPageModel

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          sortControls
          songList
          emptyState
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(Color.black)
      .overlay(alignment: .trailing) {
        SectionIndexView(
          letters: model.availableSectionLetters,
          onSelectLetter: { letter in
            withAnimation {
              proxy.scrollTo(model.scrollTargetId(forLetter: letter), anchor: .top)
            }
          }
        )
        .padding(.trailing, 4)
      }
      .navigationTitle(model.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .playolaAlert($model.presentedAlert)
      .onDisappear { Task { await model.viewDisappeared() } }
    }
  }

  private var sortControls: some View {
    HStack {
      Text(model.sortLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
        .foregroundColor(.playolaGray)

      Spacer()

      HStack(spacing: 0) {
        ForEach(model.sortModes, id: \.self) { mode in
          Button {
            model.sortModeTapped(mode)
          } label: {
            Text(model.sortSegmentTitle(for: mode))
              .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
              .foregroundColor(model.sortSegmentTextColor(for: mode))
              .padding(.horizontal, 16)
              .padding(.vertical, 6)
              .background(model.sortSegmentBackgroundColor(for: mode))
              .cornerRadius(6)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(3)
      .background(Color(hex: "#1A1A1A"))
      .cornerRadius(8)
    }
    .padding(.vertical, 8)
  }

  private var songList: some View {
    VStack(spacing: 0) {
      ForEach(model.displayedSongs, id: \.id) { block in
        songRow(block)
          .id(block.id)
        Divider()
          .background(Color.white.opacity(0.07))
      }
    }
  }

  private func songRow(_ block: AudioBlock) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        playButton(block)

        VStack(alignment: .leading, spacing: 4) {
          Text(model.songTitle(for: block))
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.white)
          Text(model.songSubtitle(for: block))
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaGray)
        }

        Spacer()

        Text(model.durationText(for: block))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#999999"))
          .monospacedDigit()
          .opacity(model.trailingDurationOpacity(for: block))
      }

      scrubber(block)
        .frame(height: model.scrubberAreaHeight(for: block))
        .opacity(model.scrubberOpacity(for: block))
        .clipped()
    }
    .padding(.vertical, 12)
    .contentShape(Rectangle())
  }

  private func playButton(_ block: AudioBlock) -> some View {
    Button {
      Task { await model.playButtonTapped(block) }
    } label: {
      ZStack {
        Circle()
          .fill(model.playButtonBackgroundColor(for: block))
          .frame(width: 44, height: 44)

        Image(systemName: model.playButtonIcon(for: block))
          .font(.system(size: 15))
          .foregroundColor(.white)
      }
    }
    .disabled(!model.isPlayButtonEnabled(for: block))
  }

  private func scrubber(_ block: AudioBlock) -> some View {
    HStack(spacing: 8) {
      Text(model.elapsedText(for: block))
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundColor(Color(hex: "#999999"))
        .monospacedDigit()

      scrubberTrack(block)

      Text(model.durationText(for: block))
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundColor(Color(hex: "#999999"))
        .monospacedDigit()
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
  }

  private func scrubberTrack(_ block: AudioBlock) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color(hex: "#5E5F5F"))
          .frame(height: 4)

        Capsule()
          .fill(Color.playolaRed)
          .frame(width: geometry.size.width * model.progress(for: block), height: 4)

        Circle()
          .fill(Color.white)
          .frame(width: 10, height: 10)
          .offset(x: geometry.size.width * model.progress(for: block) - 5)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            Task {
              await model.scrubberDragged(
                block, locationX: value.location.x, trackWidth: geometry.size.width)
            }
          }
      )
      .accessibilityElement()
      .accessibilityLabel(model.scrubberAccessibilityLabel(for: block))
      .accessibilityValue(model.scrubberAccessibilityValue(for: block))
      .accessibilityAdjustableAction { direction in
        Task { await model.scrubberAdjusted(block, increment: direction == .increment) }
      }
    }
    .frame(height: 16)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "music.note")
        .font(.system(size: 32))
        .foregroundColor(.playolaGray)
      Text(model.emptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaGray)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
    .opacity(model.emptyStateOpacity)
  }
}

#Preview {
  NavigationStack {
    MusicCategoryDetailPageView(
      model: MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(id: "1", title: "Back Down Home", artist: "Bri Bagwell", durationMS: 222_000),
          .mockWith(
            id: "2", title: "Cheat On Your Man", artist: "Bri Bagwell", durationMS: 198_000),
          .mockWith(id: "3", title: "Hard Times", artist: "Charley Crockett", durationMS: 211_000),
          .mockWith(id: "4", title: "My Boots", artist: "Bri Bagwell", durationMS: 202_000),
        ]
      )
    )
  }
  .preferredColorScheme(.dark)
}
