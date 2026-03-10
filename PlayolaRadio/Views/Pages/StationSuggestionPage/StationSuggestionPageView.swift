//
//  StationSuggestionPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct StationSuggestionPageView: View {
  @Bindable var model: StationSuggestionPageModel
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    NavigationStack {
      ZStack {
        Color.background.ignoresSafeArea()

        VStack(spacing: 0) {
          header
          content
          searchBar
        }
      }
      .navigationTitle(model.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            model.dismissTapped()
          } label: {
            Image(systemName: "xmark")
              .foregroundColor(.textPrimary)
          }
        }
      }
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarBackground(Color.background, for: .navigationBar)
      .alert(item: $model.presentedAlert) { $0.alert }
    }
    .onAppear { Task { await model.viewAppeared() } }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 4) {
      Text(model.navigationTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.textPrimary)
      Text(model.subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
    .padding(.bottom, 12)
  }

  // MARK: - Search Bar

  private var searchBar: some View {
    HStack(spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.textSecondary)
          .font(.system(size: 16))

        TextField(model.searchPlaceholder, text: $model.searchText)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.textPrimary)
          .focused($isSearchFocused)
          .autocorrectionDisabled()

        if !model.searchText.isEmpty {
          Button {
            Task { await model.clearSearchTapped() }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.textSecondary)
              .font(.system(size: 16))
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Color.cardSurface)
      .cornerRadius(10)

      if model.showSuggestButton {
        Button {
          Task { await model.suggestTapped() }
        } label: {
          Text(model.suggestButtonText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary)
            .cornerRadius(10)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.background)
    .onChange(of: model.searchText) {
      Task { await model.searchTextChanged() }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if model.isLoading {
      Spacer()
      ProgressView()
        .tint(.textSecondary)
      Spacer()
    } else if model.showEmptyState {
      Spacer()
      Text(model.emptyMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.textSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      Spacer()
    } else {
      ScrollView {
        LazyVStack(spacing: 1) {
          ForEach(model.suggestions) { suggestion in
            suggestionRow(suggestion)
          }
        }
        .padding(.top, 4)
      }
    }
  }

  // MARK: - Suggestion Row

  private func suggestionRow(_ suggestion: ArtistSuggestion) -> some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 2) {
        Text(suggestion.artistName)
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(.textPrimary)

        Text("\(model.voteCountText(suggestion)) votes")
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.textSecondary)
      }

      Spacer()

      Button {
        Task { await model.voteTapped(suggestion) }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: suggestion.hasVoted ? "heart.fill" : "heart")
            .font(.system(size: 14))
          Text(model.voteButtonText(suggestion))
            .font(.custom(FontNames.Inter_500_Medium, size: 13))
        }
        .foregroundColor(suggestion.hasVoted ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(suggestion.hasVoted ? Color.primary : Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.primary, lineWidth: suggestion.hasVoted ? 0 : 1)
        )
        .cornerRadius(18)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

#Preview {
  StationSuggestionPageView(model: StationSuggestionPageModel())
    .preferredColorScheme(.dark)
}
