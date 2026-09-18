//
//  CuratorSongPickerPageModel.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class CuratorSongPickerPageModel: ViewModel {

  enum Tab: CaseIterable, Equatable {
    case search
    case suggestions
  }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Configuration

  let stationId: String
  var onAddSong: ((AudioBlock) -> Void)?
  var onDismiss: (() -> Void)?

  // MARK: - Preview

  let preview: SongPreviewPlayer

  // MARK: - Initialization

  init(stationId: String, initialAddedSongIds: Set<String> = []) {
    self.stationId = stationId
    self.addedSongIds = initialAddedSongIds
    let preview = SongPreviewPlayer()
    self.preview = preview
    super.init()
    preview.onPlaybackError = { [weak self] message in
      self?.presentedAlert = .audioPlaybackError(message)
    }
  }

  // MARK: - Properties

  var selectedTab: Tab = .search
  var searchText: String = "" {
    didSet { onSearchTextChanged() }
  }
  var searchResults: [AudioBlock] = []
  var songRequestResults: [SongRequest] = []
  var isSearching = false

  private(set) var addedSongIds: Set<String>
  var requestedAppleIds: Set<String> = []

  var suggestions: [AudioBlock] = []
  var visibleSuggestionCount = 0
  var isLoadingSuggestions = false
  var suggestionsFailed = false

  var presentedAlert: PlayolaAlert?

  @ObservationIgnored private var processingRequestAppleIds: Set<String> = []
  @ObservationIgnored private var hasLoadedSuggestions = false
  @ObservationIgnored private var debounceTask: Task<Void, Never>?
  @ObservationIgnored private var suggestionsTask: Task<Void, Never>?

  private let suggestionsPageSize = 20

  // MARK: - User Actions

  func tabSelected(_ tab: Tab) async {
    guard tab != selectedTab else { return }
    selectedTab = tab
    await preview.stop()
  }

  func addButtonTapped(_ block: AudioBlock) {
    guard !isAdded(block) else { return }
    addedSongIds.insert(block.id)
    onAddSong?(block)
  }

  func requestButtonTapped(_ request: SongRequest) async {
    guard !isRequested(request), !processingRequestAppleIds.contains(request.appleId) else {
      return
    }
    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      return
    }
    processingRequestAppleIds.insert(request.appleId)
    defer { processingRequestAppleIds.remove(request.appleId) }
    do {
      try await api.requestSong(jwt, request)
      requestedAppleIds.insert(request.appleId)
    } catch {
      presentedAlert = .songRequestError(error.localizedDescription)
    }
  }

  func previewButtonTapped(_ block: AudioBlock) async {
    await preview.toggle(block)
  }

  func suggestionsAppeared() async {
    await startSuggestionsLoadIfNeeded()
  }

  func selectedTabAppeared() async {
    guard selectedTab == .suggestions else { return }
    await suggestionsAppeared()
  }

  func retrySuggestionsTapped() async {
    await startSuggestionsLoadIfNeeded()
  }

  func moreSuggestionsTapped() {
    visibleSuggestionCount = min(visibleSuggestionCount + suggestionsPageSize, suggestions.count)
  }

  func doneButtonTapped() {
    debounceTask?.cancel()
    suggestionsTask?.cancel()
    onDismiss?()
  }

  func viewDisappeared() async {
    debounceTask?.cancel()
    suggestionsTask?.cancel()
    await preview.stop()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Add a Song" }
  var doneButtonText: String { "Done" }
  var searchTabTitle: String { "Search" }
  var suggestionsTabTitle: String { "Suggestions" }
  var searchFieldPlaceholder: String { "Search for songs" }
  var availableNowSectionHeader: String { "AVAILABLE NOW" }
  var requestSectionHeader: String { "REQUEST FOR NEXT TIME" }
  var suggestionsSectionHeader: String { "SUGGESTED FOR THIS SHOW" }
  var searchEmptyPromptMessage: String { "Search for songs to add to your show" }
  var searchNoResultsMessage: String { "No songs found" }
  var moreSuggestionsButtonText: String { "+ More suggestions" }
  var suggestionsLoadingMessage: String { "Finding songs for your show\u{2026}" }
  var suggestionsErrorMessage: String { "We couldn\u{2019}t load suggestions." }
  var suggestionsRetryButtonText: String { "Try Again" }
  var suggestionsExhaustedMessage: String {
    "That\u{2019}s every suggestion for now. Use Search to add more."
  }

  func isAdded(_ block: AudioBlock) -> Bool {
    addedSongIds.contains(block.id)
  }

  func addButtonText(for block: AudioBlock) -> String {
    isAdded(block) ? "Added" : "Add"
  }

  func isRequested(_ request: SongRequest) -> Bool {
    request.requestStatus.isRequested || requestedAppleIds.contains(request.appleId)
  }

  func requestButtonText(for request: SongRequest) -> String {
    isRequested(request) ? "Requested" : "Request"
  }

  func rowSubtitle(for block: AudioBlock) -> String {
    "\(block.artist) \u{00B7} \(durationLabel(block.durationMS))"
  }

  var dedupedRequests: [SongRequest] {
    songRequestResults.filter { request in
      !searchResults.contains { block in Self.isSameSong(request, block) }
    }
  }

  var visibleSuggestions: [AudioBlock] {
    Array(suggestions.prefix(visibleSuggestionCount))
  }

  var canLoadMoreSuggestions: Bool {
    hasLoadedSuggestions && visibleSuggestionCount < suggestions.count
  }

  var suggestionsExhausted: Bool {
    hasLoadedSuggestions && visibleSuggestionCount >= suggestions.count
  }

  // MARK: - View Helpers (Tabs)

  var tabs: [Tab] { Tab.allCases }

  func tabTitle(_ tab: Tab) -> String {
    switch tab {
    case .search: return searchTabTitle
    case .suggestions: return suggestionsTabTitle
    }
  }

  func isTabSelected(_ tab: Tab) -> Bool { selectedTab == tab }

  func tabTextColor(_ tab: Tab) -> Color {
    isTabSelected(tab) ? .white : Color(hex: "#C7C7C7")
  }

  func tabBackgroundColor(_ tab: Tab) -> Color {
    isTabSelected(tab) ? Color(hex: "#EF6962") : .clear
  }

  func tabAccessibilityTraits(_ tab: Tab) -> AccessibilityTraits {
    isTabSelected(tab) ? [.isSelected] : []
  }

  var searchTabContentOpacity: Double { selectedTab == .search ? 1 : 0 }
  var suggestionsTabContentOpacity: Double { selectedTab == .suggestions ? 1 : 0 }
  var searchTabInteractive: Bool { selectedTab == .search }
  var suggestionsTabInteractive: Bool { selectedTab == .suggestions }
  var searchTabAccessibilityHidden: Bool { selectedTab != .search }
  var suggestionsTabAccessibilityHidden: Bool { selectedTab != .suggestions }

  // MARK: - View Helpers (Search states)

  private var trimmedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var hasSearchContent: Bool {
    !searchResults.isEmpty || !dedupedRequests.isEmpty
  }

  var searchLoadingOpacity: Double { isSearching ? 1 : 0 }
  var searchLoadingAccessibilityHidden: Bool { !isSearching }

  var searchEmptyPromptOpacity: Double {
    (!isSearching && trimmedSearchText.isEmpty) ? 1 : 0
  }
  var searchEmptyPromptAccessibilityHidden: Bool {
    isSearching || !trimmedSearchText.isEmpty
  }

  var searchNoResultsOpacity: Double {
    (!isSearching && !trimmedSearchText.isEmpty && !hasSearchContent) ? 1 : 0
  }
  var searchNoResultsAccessibilityHidden: Bool {
    isSearching || trimmedSearchText.isEmpty || hasSearchContent
  }

  var availableNowHeaders: [String] {
    searchResults.isEmpty ? [] : [availableNowSectionHeader]
  }
  var requestHeaders: [String] {
    dedupedRequests.isEmpty ? [] : [requestSectionHeader]
  }

  func songTitle(for block: AudioBlock) -> String { block.title }

  func addButtonBackgroundColor(for block: AudioBlock) -> Color {
    isAdded(block) ? Color(hex: "#2A2A2A") : Color(hex: "#EF6962")
  }
  func addButtonTextColor(for block: AudioBlock) -> Color {
    isAdded(block) ? Color(hex: "#C7C7C7") : .white
  }
  func isAddButtonEnabled(for block: AudioBlock) -> Bool { !isAdded(block) }
  func addButtonAccessibilityTraits(for block: AudioBlock) -> AccessibilityTraits {
    isAdded(block) ? [.isSelected] : []
  }

  func requestTitle(for request: SongRequest) -> String { request.title }
  func requestSubtitle(for request: SongRequest) -> String { request.artist }

  func requestButtonBackgroundColor(for request: SongRequest) -> Color {
    isRequested(request) ? Color(hex: "#2A2A2A") : Color(hex: "#EF6962")
  }
  func requestButtonTextColor(for request: SongRequest) -> Color {
    isRequested(request) ? Color(hex: "#C7C7C7") : .white
  }
  func isRequestButtonEnabled(for request: SongRequest) -> Bool { !isRequested(request) }
  func requestButtonAccessibilityTraits(for request: SongRequest) -> AccessibilityTraits {
    isRequested(request) ? [.isSelected] : []
  }

  // MARK: - View Helpers (Suggestions states)

  var suggestionsHeaders: [String] {
    visibleSuggestions.isEmpty ? [] : [suggestionsSectionHeader]
  }
  var suggestionsLoadingOpacity: Double { isLoadingSuggestions ? 1 : 0 }
  var suggestionsLoadingAccessibilityHidden: Bool { !isLoadingSuggestions }
  var suggestionsErrorOpacity: Double { suggestionsFailed ? 1 : 0 }
  var suggestionsErrorAccessibilityHidden: Bool { !suggestionsFailed }
  var moreSuggestionsButtons: [String] {
    canLoadMoreSuggestions ? [moreSuggestionsButtonText] : []
  }
  var suggestionsExhaustedMessages: [String] {
    suggestionsExhausted ? [suggestionsExhaustedMessage] : []
  }

  // MARK: - Private Helpers

  private func onSearchTextChanged() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await clock.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await performSearch(searchText)
      } catch {
        // Task was cancelled
      }
    }
  }

  private func performSearch(_ query: String) async {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedQuery.isEmpty else {
      searchResults = []
      songRequestResults = []
      isSearching = false
      return
    }

    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      isSearching = false
      return
    }

    isSearching = true
    async let songs = searchSongs(jwt: jwt, query: trimmedQuery)
    async let requests = searchSongRequests(jwt: jwt, query: trimmedQuery)
    let (foundSongs, foundRequests) = await (songs, requests)
    // Publish both halves in the same tick so `dedupedRequests` is never computed against a
    // half-updated result set (a library song could otherwise surface as a requestable row), and
    // bail if a newer search has since superseded this one so it can't clear the live spinner.
    guard !Task.isCancelled else { return }
    searchResults = foundSongs
    songRequestResults = foundRequests
    isSearching = false
  }

  private func searchSongs(jwt: String, query: String) async -> [AudioBlock] {
    do {
      return try await api.searchSongs(jwt, query)
    } catch {
      guard !Task.isCancelled else { return [] }
      presentedAlert = .searchError(error.localizedDescription)
      return []
    }
  }

  private func searchSongRequests(jwt: String, query: String) async -> [SongRequest] {
    (try? await api.searchSongRequests(jwt, query)) ?? []
  }

  // The fetch is owned here (not by the view's `.task(id:)`) so switching away from and back to the
  // Suggestions tab can't cancel it mid-flight and strand the tab in a failed/blank state; it is
  // cancelled only when the sheet is dismissed. Awaiting the task keeps callers (and tests)
  // synchronous with completion.
  private func startSuggestionsLoadIfNeeded() async {
    guard !hasLoadedSuggestions, suggestionsTask == nil else { return }
    let task = Task { [weak self] in
      guard let self else { return }
      await loadSuggestions()
    }
    suggestionsTask = task
    await task.value
    suggestionsTask = nil
  }

  private func loadSuggestions() async {
    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      return
    }
    isLoadingSuggestions = true
    suggestionsFailed = false
    do {
      let fetched = try await api.getSongSuggestions(jwt, stationId)
      var seenIds = Set<String>()
      let uniqueBlocks = fetched.map(\.audioBlock).filter { seenIds.insert($0.id).inserted }
      suggestions = uniqueBlocks
      visibleSuggestionCount = min(suggestionsPageSize, uniqueBlocks.count)
      hasLoadedSuggestions = true
    } catch {
      // A cancellation (sheet dismissed) is not a load failure: leave the tab retryable rather than
      // showing the error state.
      if !Task.isCancelled {
        suggestionsFailed = true
      }
    }
    isLoadingSuggestions = false
  }

  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  // Dedup match order: appleId, then isrc, then spotifyId, then normalized title+artist. Each key
  // decides only when BOTH sides carry a non-empty value; two nils/empties never match.
  private static func isSameSong(_ request: SongRequest, _ block: AudioBlock) -> Bool {
    if let requestApple = nonEmpty(request.appleId), let blockApple = nonEmpty(block.appleId) {
      return requestApple == blockApple
    }
    if let requestIsrc = nonEmpty(request.isrc), let blockIsrc = nonEmpty(block.isrc) {
      return requestIsrc == blockIsrc
    }
    if let requestSpotify = nonEmpty(request.spotifyId),
      let blockSpotify = nonEmpty(block.spotifyId)
    {
      return requestSpotify == blockSpotify
    }
    let requestTitle = normalized(request.title)
    let requestArtist = normalized(request.artist)
    let blockTitle = normalized(block.title)
    let blockArtist = normalized(block.artist)
    guard !requestTitle.isEmpty, !requestArtist.isEmpty, !blockTitle.isEmpty, !blockArtist.isEmpty
    else {
      return false
    }
    return requestTitle == blockTitle && requestArtist == blockArtist
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
