import PlayolaPlayer
import SwiftUI

struct LikedSongsPage: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: LikedSongsPageModel
  @State private var removingAudioBlockIds: Set<String> = []

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Button(
          action: { dismiss() },
          label: {
            Image(systemName: "chevron.left")
              .foregroundColor(.white)
              .font(.system(size: 20))
          })

        Spacer()

        Text("Liked Songs")
          .font(.custom(FontNames.Inter_500_Medium, size: 20))
          .foregroundColor(.white)

        Spacer()

        // Empty spacer to balance the back button
        Color.clear
          .frame(width: 20, height: 20)
      }
      .padding(.horizontal, 24)
      .padding(.top, 8)
      .padding(.bottom, 16)

      // Songs List
      if model.groupedLikedSongs.isEmpty {
        Spacer()
        Text("No liked songs yet")
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(Color(hex: "#C7C7C7"))
        Spacer()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.groupedLikedSongs, id: \.0) { section in
              let (sectionTitle, songsWithTimestamps) = section

              // Section Header
              Text(sectionTitle)
                .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

              // Songs in Section
              ForEach(songsWithTimestamps, id: \.0.id) { audioBlockWithTimestamp in
                let (audioBlock, likedDate) = audioBlockWithTimestamp
                if !removingAudioBlockIds.contains(audioBlock.id) {
                  SongRow(audioBlock: audioBlock, likedDate: likedDate, model: model)
                    .transition(
                      .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                      ))
                }
              }
            }
          }
          .animation(.easeInOut(duration: 0.3), value: removingAudioBlockIds)
        }
        .scrollIndicators(.hidden)
      }
    }
    .background(Color.black)
    .navigationBarHidden(true)
    .sheet(item: $model.presentedSongActionSheet) { sheet in
      SongDrawerView(
        model: SongDrawerModel(
          audioBlock: sheet.audioBlock,
          likedDate: sheet.likedDate,
          onDismiss: { model.presentedSongActionSheet = nil },
          onRemove: { audioBlock in animateRemoval(of: audioBlock) }
        )
      )
      .presentationCornerRadius(20)
      .presentationDetents([.height(320), .medium])
      .presentationDragIndicator(.visible)
      .presentationBackground(Color(hex: "#323232"))
    }
  }

  private func animateRemoval(of audioBlock: AudioBlock) {
    // Add to removing set for animation
    removingAudioBlockIds.insert(audioBlock.id)

    // Remove from data after animation completes
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
      model.removeSong(audioBlock)
      removingAudioBlockIds.remove(audioBlock.id)
    }
  }
}

struct SongRow: View {
  let audioBlock: AudioBlock
  let likedDate: Date
  let model: LikedSongsPageModel

  var body: some View {
    HStack(spacing: 12) {
      // Album Art Placeholder
      AsyncImage(url: audioBlock.imageUrl) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color(hex: "#666666"))
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
              .font(.system(size: 24))
          )
      }
      .frame(width: 56, height: 56)
      .cornerRadius(6)

      // Song Info
      VStack(alignment: .leading, spacing: 2) {
        Text(audioBlock.title)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(audioBlock.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .lineLimit(1)

        Text(model.formatTimestamp(for: likedDate))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#888888"))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      // Menu Button
      Button(
        action: { model.menuButtonTapped(for: audioBlock, likedDate: likedDate) },
        label: {
          Image(systemName: "ellipsis")
            .foregroundColor(Color(hex: "#C7C7C7"))
            .font(.system(size: 16))
        }
      )
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 8)
  }
}

#Preview {
  LikedSongsPage(model: LikedSongsPageModel())
    .preferredColorScheme(.dark)
}
