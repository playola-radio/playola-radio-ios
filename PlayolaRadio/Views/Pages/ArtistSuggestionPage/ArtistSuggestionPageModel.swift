//
//  ArtistSuggestionPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class ArtistSuggestionPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Properties

  var suggestions: [ArtistSuggestion] = []
  var searchText = ""
  var isLoading = false
  var presentedAlert: PlayolaAlert?
  var onDismiss: (() -> Void)?

  let navigationTitle = "Suggest a Station"
  let subtitle = "Who's station should we build next?"
  let searchPlaceholder = "Search suggestions..."
  let emptyStateMessage = "No suggestions yet. Be the first!"
  let emptySearchMessage = "No results found"
  let suggestButtonText = "Suggest"

  // MARK: - User Actions

  func viewAppeared() async {
    await fetchSuggestions()
  }

  func dismissTapped() {
    onDismiss?()
  }

  func searchTextChanged() async {
    await fetchSuggestions()
  }

  func clearSearchTapped() async {
    searchText = ""
    await fetchSuggestions()
  }

  func voteTapped(_ suggestion: ArtistSuggestion) async {
    guard let jwt = auth.jwt else { return }

    do {
      if suggestion.hasVoted {
        try await api.removeArtistSuggestionVote(jwt, suggestion.id)
      } else {
        try await api.voteForArtistSuggestion(jwt, suggestion.id)
      }
      await fetchSuggestions()
    } catch {
      presentedAlert = PlayolaAlert(
        title: "Error",
        message: "Could not update vote: \(error.localizedDescription)",
        dismissButton: .cancel(Text("OK"))
      )
    }
  }

  func suggestTapped() async {
    let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, let jwt = auth.jwt else { return }

    do {
      _ = try await api.createArtistSuggestion(jwt, name)
      searchText = ""
      await fetchSuggestions()
    } catch {
      presentedAlert = PlayolaAlert(
        title: "Error",
        message: "Could not create suggestion: \(error.localizedDescription)",
        dismissButton: .cancel(Text("OK"))
      )
    }
  }

  // MARK: - View Helpers

  var showSuggestButton: Bool {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return !suggestions.contains {
      $0.artistName.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
    }
  }

  var showEmptyState: Bool {
    !isLoading && suggestions.isEmpty
  }

  var emptyMessage: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? emptyStateMessage
      : emptySearchMessage
  }

  func voteButtonText(_ suggestion: ArtistSuggestion) -> String {
    suggestion.hasVoted ? "Voted" : "Vote"
  }

  func voteCountText(_ suggestion: ArtistSuggestion) -> String {
    "\(suggestion.voteCount)"
  }

  // MARK: - Private Helpers

  private func fetchSuggestions() async {
    guard let jwt = auth.jwt else { return }

    isLoading = suggestions.isEmpty
    do {
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      suggestions = try await api.getArtistSuggestions(jwt, query.isEmpty ? nil : query)
    } catch {
      presentedAlert = PlayolaAlert(
        title: "Error",
        message: "Could not load suggestions: \(error.localizedDescription)",
        dismissButton: .cancel(Text("OK"))
      )
    }
    isLoading = false
  }
}
