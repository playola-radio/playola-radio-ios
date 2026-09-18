//
//  CuratorSongPickerPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct CuratorSongPickerPageView: View {
  @Bindable var model: CuratorSongPickerPageModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 0) {
        segmentedControl

        ZStack {
          searchTab
            .opacity(model.searchTabContentOpacity)
            .allowsHitTesting(model.searchTabInteractive)
            .accessibilityHidden(model.searchTabAccessibilityHidden)

          suggestionsTab
            .opacity(model.suggestionsTabContentOpacity)
            .allowsHitTesting(model.suggestionsTabInteractive)
            .accessibilityHidden(model.suggestionsTabAccessibilityHidden)
        }
      }
    }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(model.doneButtonText) { model.doneButtonTapped() }
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.playolaRed)
      }
    }
    .playolaAlert($model.presentedAlert)
    .task(id: model.selectedTab) { await model.selectedTabAppeared() }
    .onDisappear { Task { await model.viewDisappeared() } }
  }

  // MARK: - Segmented control

  private var segmentedControl: some View {
    HStack(spacing: 4) {
      ForEach(model.tabs, id: \.self) { tab in
        Button {
          Task { await model.tabSelected(tab) }
        } label: {
          Text(model.tabTitle(tab))
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(model.tabTextColor(tab))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(model.tabBackgroundColor(tab))
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.tabAccessibilityTraits(tab))
      }
    }
    .padding(4)
    .background(Color(hex: "#2A2A2A"))
    .clipShape(.rect(cornerRadius: 10))
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 12)
  }

  // MARK: - Search tab

  private var searchTab: some View {
    VStack(spacing: 0) {
      ZStack {
        searchResultsList
        searchLoadingState
        searchEmptyPrompt
        searchNoResults
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      searchField
    }
  }

  private var searchResultsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(model.availableNowHeaders, id: \.self) { header in
          sectionHeader(header)
        }
        ForEach(model.searchResults, id: \.id) { block in
          CuratorSongRow(model: model, block: block)
        }

        ForEach(model.requestHeaders, id: \.self) { header in
          sectionHeader(header)
        }
        ForEach(model.dedupedRequests, id: \.id) { request in
          CuratorRequestRow(model: model, request: request)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
  }

  private var searchLoadingState: some View {
    ProgressView()
      .tint(.white)
      .opacity(model.searchLoadingOpacity)
      .accessibilityHidden(model.searchLoadingAccessibilityHidden)
  }

  private var searchEmptyPrompt: some View {
    centeredMessage(systemImage: "music.note.list", text: model.searchEmptyPromptMessage)
      .opacity(model.searchEmptyPromptOpacity)
      .accessibilityHidden(model.searchEmptyPromptAccessibilityHidden)
  }

  private var searchNoResults: some View {
    centeredMessage(systemImage: "magnifyingglass", text: model.searchNoResultsMessage)
      .opacity(model.searchNoResultsOpacity)
      .accessibilityHidden(model.searchNoResultsAccessibilityHidden)
  }

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16))
        .foregroundColor(.playolaGray)

      TextField(model.searchFieldPlaceholder, text: $model.searchText)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.white)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(hex: "#2A2A2A"))
    .clipShape(.rect(cornerRadius: 8))
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.black)
  }

  // MARK: - Suggestions tab

  private var suggestionsTab: some View {
    ZStack {
      suggestionsList
      suggestionsLoadingState
      suggestionsErrorState
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var suggestionsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(model.suggestionsHeaders, id: \.self) { header in
          sectionHeader(header)
        }
        ForEach(model.visibleSuggestions, id: \.id) { block in
          CuratorSongRow(model: model, block: block)
        }

        ForEach(model.moreSuggestionsButtons, id: \.self) { title in
          Button {
            model.moreSuggestionsTapped()
          } label: {
            Text(title)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
              .foregroundColor(.playolaRed)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .buttonStyle(.plain)
        }

        ForEach(model.suggestionsExhaustedMessages, id: \.self) { message in
          Text(message)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(.playolaGray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  private var suggestionsLoadingState: some View {
    VStack(spacing: 12) {
      ProgressView().tint(.white)
      Text(model.suggestionsLoadingMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaGray)
    }
    .opacity(model.suggestionsLoadingOpacity)
    .accessibilityHidden(model.suggestionsLoadingAccessibilityHidden)
  }

  private var suggestionsErrorState: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 40))
        .foregroundColor(.playolaGray)
      Text(model.suggestionsErrorMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
      Button {
        Task { await model.retrySuggestionsTapped() }
      } label: {
        Text(model.suggestionsRetryButtonText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color(hex: "#EF6962"))
          .clipShape(.rect(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 40)
    .opacity(model.suggestionsErrorOpacity)
    .accessibilityHidden(model.suggestionsErrorAccessibilityHidden)
  }

  // MARK: - Shared subviews

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
      .foregroundColor(.playolaGray)
      .padding(.top, 16)
      .padding(.bottom, 8)
  }

  private func centeredMessage(systemImage: String, text: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 48))
        .foregroundColor(.playolaGray)
      Text(text)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 40)
  }
}

// MARK: - Song row (library + suggestions)

struct CuratorSongRow: View {
  let model: CuratorSongPickerPageModel
  let block: AudioBlock

  var body: some View {
    HStack(spacing: 12) {
      CuratorArtworkView(url: block.imageUrl)
        .overlay {
          CuratorPreviewPlayButton(model: model, block: block)
        }

      VStack(alignment: .leading, spacing: 2) {
        Text(model.songTitle(for: block))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.white)
          .lineLimit(1)
        Text(model.rowSubtitle(for: block))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()

      Button {
        model.addButtonTapped(block)
      } label: {
        Text(model.addButtonText(for: block))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
          .foregroundColor(model.addButtonTextColor(for: block))
          .padding(.horizontal, 16)
          .padding(.vertical, 7)
          .background(model.addButtonBackgroundColor(for: block))
          .clipShape(.rect(cornerRadius: 16))
      }
      .buttonStyle(.plain)
      .disabled(!model.isAddButtonEnabled(for: block))
      .accessibilityAddTraits(model.addButtonAccessibilityTraits(for: block))
    }
    .padding(.vertical, 8)
  }
}

// MARK: - Request row (de-emphasized, no preview/duration)

struct CuratorRequestRow: View {
  let model: CuratorSongPickerPageModel
  let request: SongRequest

  var body: some View {
    HStack(spacing: 12) {
      CuratorArtworkView(url: request.imageUrl)
        .opacity(0.7)

      VStack(alignment: .leading, spacing: 2) {
        Text(model.requestTitle(for: request))
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .lineLimit(1)
        Text(model.requestSubtitle(for: request))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()

      Button {
        Task { await model.requestButtonTapped(request) }
      } label: {
        Text(model.requestButtonText(for: request))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
          .foregroundColor(model.requestButtonTextColor(for: request))
          .padding(.horizontal, 16)
          .padding(.vertical, 7)
          .background(model.requestButtonBackgroundColor(for: request))
          .clipShape(.rect(cornerRadius: 16))
      }
      .buttonStyle(.plain)
      .disabled(!model.isRequestButtonEnabled(for: request))
      .accessibilityAddTraits(model.requestButtonAccessibilityTraits(for: request))
    }
    .padding(.vertical, 8)
  }
}

// MARK: - Artwork

struct CuratorArtworkView: View {
  @Environment(\.displayScale) private var displayScale
  let url: URL?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color(hex: "#2A2A2A"))
        .overlay {
          Image(systemName: "music.note")
            .foregroundColor(Color(hex: "#666666"))
        }

      WebImage(
        url: url,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 48, height: 48), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
    }
    .frame(width: 48, height: 48)
    .clipShape(.rect(cornerRadius: 6))
  }
}

// MARK: - Preview play button (observes only the preview engine)

struct CuratorPreviewPlayButton: View {
  let model: CuratorSongPickerPageModel
  let block: AudioBlock

  var body: some View {
    Button {
      Task { await model.previewButtonTapped(block) }
    } label: {
      ZStack {
        Circle()
          .fill(Color.black.opacity(0.45))
          .frame(width: 28, height: 28)

        ProgressView()
          .progressViewStyle(.circular)
          .tint(.white)
          .scaleEffect(0.7)
          .opacity(model.preview.bufferingSpinnerOpacity(for: block))

        Image(systemName: model.preview.playButtonIcon(for: block))
          .font(.system(size: 12))
          .foregroundColor(.white)
          .opacity(model.preview.playIconOpacity(for: block))
      }
    }
    .buttonStyle(.plain)
    .disabled(!model.preview.isPlayButtonEnabled(for: block))
    .accessibilityLabel(model.songTitle(for: block))
  }
}
