import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct ListeningHistoryPageView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale
  @Bindable var model: ListeningHistoryPageModel

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 18) {
        Button(
          action: { dismiss() },
          label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 22, weight: .semibold))
              .foregroundColor(.white)
          }
        )
        .accessibilityLabel("Back to Your Library")
        Text(model.navigationTitle)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)

      GeometryReader { geometry in
        ScrollView {
          Group {
            switch model.displayState {
            case .idle, .loading:
              loadingContent
            case .empty:
              stateContent(
                symbol: "music.note",
                title: "No listening history yet",
                message: "Songs you hear on Playola channels will appear here.",
                buttonTitle: "Explore Stations",
                action: model.exploreStationsButtonTapped
              )
            case .error:
              stateContent(
                symbol: "wifi.slash",
                title: "Couldn’t load your history",
                message: "Check your connection and try again.",
                buttonTitle: "Try Again",
                action: { Task { await model.retryButtonTapped() } }
              )
            case .signedOut:
              stateContent(
                symbol: "person.crop.circle",
                title: "Sign in to see your history",
                message: "Your listening history is tied to your account.",
                buttonTitle: "Sign In",
                action: { Task { await model.signInButtonTapped() } }
              )
            case .loaded:
              historyContent
            }
          }
          .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.refreshRequested() }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .navigationBarHidden(true)
    .task { await model.detailAppeared() }
  }

  private var historyContent: some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(model.sections) { section in
        Text(section.title)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 23))
          .foregroundColor(.white)
          .padding(.top, 24)
          .padding(.bottom, 14)

        ForEach(section.spins) { spin in
          historyRow(spin)
            .padding(.bottom, 24)
            .onAppear {
              Task { await model.loadMoreIfNeeded(visibleSpinID: spin.id) }
            }
        }
      }

      if model.isLoadingMore {
        ProgressView()
          .tint(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
      } else if model.loadMoreFailed {
        HStack(spacing: 8) {
          Text("Couldn’t load more songs.")
            .foregroundColor(Color(hex: "#C7C7C7"))
          Button("Retry") { Task { await model.loadMoreRetryButtonTapped() } }
            .foregroundColor(Color(hex: "#EF6662"))
        }
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func historyRow(_ spin: ListeningHistorySpin) -> some View {
    HStack(spacing: 12) {
      if let audioBlock = spin.audioBlock {
        WebImage(
          url: audioBlock.imageUrl,
          context: RemoteArtwork.downsampleContext(
            CGSize(width: 56, height: 56), scale: displayScale)
        ) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          RoundedRectangle(cornerRadius: 7)
            .fill(Color(hex: "#666666"))
            .overlay {
              Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#B5B5B5"))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 7))

        VStack(alignment: .leading, spacing: 3) {
          Text(audioBlock.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
          Text(audioBlock.artist)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(Color(hex: "#D1D1D1"))
          Text(model.subtitle(for: spin))
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(Color(hex: "#A9A9A9"))
        }
        .lineLimit(1)

        Spacer(minLength: 4)

        Button(
          action: { model.heartButtonTapped(for: spin) },
          label: {
            Image(systemName: model.isLiked(spin) ? "heart.fill" : "heart")
              .font(.system(size: 22))
              .foregroundColor(.white)
              .frame(width: 42, height: 42)
              .background(Color(hex: "#303030"), in: Circle())
          }
        )
        .accessibilityLabel(model.isLiked(spin) ? "Remove from Favorites" : "Add to Favorites")
      }
    }
  }

  private var loadingContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      ForEach(0..<5, id: \.self) { _ in
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: 7)
            .fill(Color(hex: "#303030"))
            .frame(width: 56, height: 56)
          VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(hex: "#303030"))
              .frame(width: 190, height: 14)
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(hex: "#303030"))
              .frame(width: 120, height: 12)
          }
          Spacer()
        }
      }
      Spacer()
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func stateContent(
    symbol: String,
    title: String,
    message: String,
    buttonTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 16) {
      Image(systemName: symbol)
        .font(.system(size: 40))
        .foregroundColor(Color(hex: "#C7C7C7"))
      Text(title)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 23))
        .foregroundColor(.white)
      Text(message)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(Color(hex: "#C7C7C7"))
        .multilineTextAlignment(.center)
      Button(action: action) {
        Text(buttonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)
          .padding(.horizontal, 22)
          .padding(.vertical, 13)
          .background(Color(hex: "#EF6662"), in: RoundedRectangle(cornerRadius: 14))
      }
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
