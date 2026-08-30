//
//  BreakerCategoryDetailPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct BreakerCategoryDetailPageView: View {
  @Bindable var model: BreakerCategoryDetailPageModel

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        clipList
        emptyState
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .background(Color.black)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .playolaAlert($model.presentedAlert)
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  private var clipList: some View {
    VStack(spacing: 0) {
      ForEach(model.clips, id: \.id) { block in
        clipRow(block)
        Divider()
          .background(Color(hex: "#333333"))
      }
    }
  }

  private func clipRow(_ block: AudioBlock) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        playButton(block)

        VStack(alignment: .leading, spacing: 4) {
          Text(model.clipTitle(for: block))
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(.white)
          Text(model.clipSubtitle(for: block))
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
        }

        Spacer()
      }

      scrubber(block)
    }
    .padding(.vertical, 16)
  }

  private func playButton(_ block: AudioBlock) -> some View {
    Button {
      Task { await model.playButtonTapped(block) }
    } label: {
      ZStack {
        Circle()
          .fill(model.playButtonBackgroundColor(for: block))
          .frame(width: 52, height: 52)

        Image(systemName: model.playButtonIcon(for: block))
          .font(.system(size: 18))
          .foregroundColor(.white)
      }
    }
    .disabled(!model.isPlayButtonEnabled(for: block))
  }

  private func scrubber(_ block: AudioBlock) -> some View {
    HStack(spacing: 8) {
      Text(model.elapsedText(for: block))
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.playolaGray)
        .monospacedDigit()

      scrubberTrack(block)

      Text(model.durationText(for: block))
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.playolaGray)
        .monospacedDigit()
    }
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
          .frame(width: 14, height: 14)
          .offset(x: geometry.size.width * model.progress(for: block) - 7)
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
    }
    .frame(height: 20)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "square.stack")
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
    BreakerCategoryDetailPageView(
      model: BreakerCategoryDetailPageModel(
        category: .mockWith(
          name: "Intros",
          audioBlocks: [
            .mockWith(
              id: "1", title: "Reckless Radio Open", artist: "Bri Bagwell", durationMS: 12_000),
            .mockWith(
              id: "2", title: "Late Night Welcome", artist: "Bri Bagwell", durationMS: 9_000),
            .mockWith(
              id: "3", title: "Texas Country Hour", artist: "Station Voice", durationMS: 15_000),
          ]
        )
      )
    )
  }
  .preferredColorScheme(.dark)
}
