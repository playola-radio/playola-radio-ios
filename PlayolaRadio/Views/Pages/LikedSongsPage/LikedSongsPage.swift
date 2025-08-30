import PlayolaPlayer
import SwiftUI

struct LikedSongsPage: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: LikedSongsPageModel

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
              let (sectionTitle, songs) = section

              // Section Header
              Text(sectionTitle)
                .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

              // Songs in Section
              ForEach(songs, id: \.id) { audioBlock in
                SongRow(audioBlock: audioBlock, model: model)
              }
            }
          }
        }
        .scrollIndicators(.hidden)
      }
    }
    .background(Color.black)
    .navigationBarHidden(true)
  }
}

struct SongRow: View {
  let audioBlock: AudioBlock
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

        Text(model.formatTimestamp(for: audioBlock))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#888888"))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      // Menu Button
      Button(action: { model.menuButtonTapped(for: audioBlock) }) {
        Image(systemName: "ellipsis")
          .foregroundColor(Color(hex: "#C7C7C7"))
          .font(.system(size: 16))
          .rotationEffect(.degrees(90))
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 8)
  }
}

#Preview {
  LikedSongsPage(model: LikedSongsPageModel())
    .preferredColorScheme(.dark)
}
