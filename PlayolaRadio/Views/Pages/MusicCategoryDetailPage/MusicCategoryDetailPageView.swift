//
//  MusicCategoryDetailPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct MusicCategoryDetailPageView: View {
  @Bindable var model: MusicCategoryDetailPageModel

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        songList
        emptyState
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .background(Color.black)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var songList: some View {
    VStack(spacing: 0) {
      ForEach(model.songs, id: \.id) { block in
        songRow(block)
        Divider()
          .background(Color(hex: "#333333"))
      }
    }
  }

  private func songRow(_ block: AudioBlock) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.songTitle(for: block))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
          .foregroundColor(.white)
        Text(model.songSubtitle(for: block))
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaGray)
      }
      Spacer()
    }
    .padding(.vertical, 16)
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
        title: "Texas Country",
        songs: [
          .mockWith(id: "1", title: "Whiskey Sunset", artist: "Bri Bagwell", durationMS: 210_000),
          .mockWith(
            id: "2", title: "Dance Hall Nights", artist: "Josh Abbott", durationMS: 195_000),
        ]
      )
    )
  }
  .preferredColorScheme(.dark)
}
