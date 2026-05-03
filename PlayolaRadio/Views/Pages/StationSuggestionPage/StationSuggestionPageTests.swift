//
//  StationSuggestionPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/10/26.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationSuggestionPageTests {

  // MARK: - Test Data

  private let testJwt = "test-jwt-token"

  nonisolated private func mockSuggestions() -> [ArtistSuggestion] {
    [
      ArtistSuggestion(
        id: "s1", artistName: "Bri Bagwell", createdByUserId: "u1",
        voteCount: 10, hasVoted: true, createdAt: Date(), updatedAt: Date()),
      ArtistSuggestion(
        id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
        voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date()),
      ArtistSuggestion(
        id: "s3", artistName: "Colter Wall", createdByUserId: "u3",
        voteCount: 3, hasVoted: false, createdAt: Date(), updatedAt: Date()),
    ]
  }

  private func makeModel(
    suggestions: [ArtistSuggestion]? = nil,
    onGetSuggestions: (
      @Sendable (_ jwt: String, _ search: String?) async throws -> [ArtistSuggestion]
    )? = nil,
    onCreate: (@Sendable (_ jwt: String, _ name: String) async throws -> ArtistSuggestion)? = nil,
    onVote: (@Sendable (_ jwt: String, _ id: String) async throws -> Void)? = nil,
    onRemoveVote: (@Sendable (_ jwt: String, _ id: String) async throws -> Void)? = nil
  ) -> StationSuggestionPageModel {
    let defaultSuggestions = suggestions ?? mockSuggestions()
    let defaultGet: @Sendable (String, String?) async throws -> [ArtistSuggestion] = { _, _ in
      defaultSuggestions
    }
    let defaultCreate: @Sendable (String, String) async throws -> ArtistSuggestion = { _, name in
      ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    }
    let defaultVote: @Sendable (String, String) async throws -> Void = { _, _ in }
    let defaultRemoveVote: @Sendable (String, String) async throws -> Void = { _, _ in }
    return withDependencies {
      $0.api.getArtistSuggestions = onGetSuggestions ?? defaultGet
      $0.api.createArtistSuggestion = onCreate ?? defaultCreate
      $0.api.voteForArtistSuggestion = onVote ?? defaultVote
      $0.api.removeArtistSuggestionVote = onRemoveVote ?? defaultRemoveVote
    } operation: {
      StationSuggestionPageModel()
    }
  }

  // MARK: - View Appeared Tests

  @Test
  func testViewAppearedFetchesSuggestions() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel()

    await model.viewAppeared()

    #expect(model.suggestions.count == 3)
    #expect(model.suggestions.first?.artistName == "Bri Bagwell")
  }

  @Test
  func testViewAppearedDoesNothingWithoutAuth() async {
    @Shared(.auth) var auth = Auth()
    let model = makeModel()

    await model.viewAppeared()

    #expect(model.suggestions.isEmpty)
  }

  @Test
  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onGetSuggestions: { _, _ in
      throw APIError.dataNotValid
    })

    await model.viewAppeared()

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Error")
  }

  // MARK: - Search Tests

  @Test
  func testSearchTextChangedFetchesWithQuery() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedSearches = LockIsolated<[String?]>([])
    let model = makeModel(onGetSuggestions: { _, search in
      capturedSearches.withValue { $0.append(search) }
      return []
    })

    model.searchText = "Charley"
    await model.searchTextChanged()

    let searches = capturedSearches.value
    #expect(searches.last == "Charley")
  }

  @Test
  func testSearchTextChangedSendsNilForEmptyQuery() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedSearches = LockIsolated<[String?]>([])
    let model = makeModel(onGetSuggestions: { _, search in
      capturedSearches.withValue { $0.append(search) }
      return []
    })

    model.searchText = ""
    await model.searchTextChanged()

    let searches = capturedSearches.value
    #expect((searches.last ?? nil) == nil)
  }

  @Test
  func testClearSearchTappedResetsTextAndFetches() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedSearches = LockIsolated<[String?]>([])
    let model = makeModel(onGetSuggestions: { _, search in
      capturedSearches.withValue { $0.append(search) }
      return self.mockSuggestions()
    })

    model.searchText = "Charley"
    await model.clearSearchTapped()

    #expect(model.searchText == "")
    #expect((capturedSearches.value.last ?? nil) == nil)
    #expect(model.suggestions.count == 3)
  }

  // MARK: - Vote Tests

  @Test
  func testVoteTappedCallsVoteForUnvotedSuggestion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedVoteIds = LockIsolated<[String]>([])
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onVote: { _, id in
      capturedVoteIds.withValue { $0.append(id) }
    })

    await model.voteTapped(unvotedSuggestion)

    #expect(capturedVoteIds.value == ["s2"])
  }

  @Test
  func testVoteTappedCallsRemoveVoteForVotedSuggestion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedRemoveIds = LockIsolated<[String]>([])
    let votedSuggestion = ArtistSuggestion(
      id: "s1", artistName: "Bri Bagwell", createdByUserId: "u1",
      voteCount: 10, hasVoted: true, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onRemoveVote: { _, id in
      capturedRemoveIds.withValue { $0.append(id) }
    })

    await model.voteTapped(votedSuggestion)

    #expect(capturedRemoveIds.value == ["s1"])
  }

  @Test
  func testVoteTappedRefetchesSuggestionsAfterSuccess() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let fetchCount = LockIsolated(0)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onGetSuggestions: { _, _ in
      fetchCount.withValue { $0 += 1 }
      return self.mockSuggestions()
    })

    await model.voteTapped(unvotedSuggestion)

    #expect(fetchCount.value >= 1)
  }

  @Test
  func testVoteTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onVote: { _, _ in
      throw APIError.validationError("Already voted")
    })

    await model.voteTapped(unvotedSuggestion)

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Error")
  }

  @Test
  func testVoteTappedDoesNothingWithoutAuth() async {
    @Shared(.auth) var auth = Auth()
    let capturedVoteIds = LockIsolated<[String]>([])
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Bri Bagwell", createdByUserId: "u1",
      voteCount: 10, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onVote: { _, id in
      capturedVoteIds.withValue { $0.append(id) }
    })

    await model.voteTapped(suggestion)

    #expect(capturedVoteIds.value.isEmpty)
  }

  // MARK: - Suggest Tests

  @Test
  func testSuggestTappedCreatesAndClearsSearch() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedNames = LockIsolated<[String]>([])
    let model = makeModel(onCreate: { _, name in
      capturedNames.withValue { $0.append(name) }
      return ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    })

    model.searchText = "Tyler Childers"
    await model.suggestTapped()

    #expect(capturedNames.value == ["Tyler Childers"])
    #expect(model.searchText == "")
  }

  @Test
  func testSuggestTappedTrimsWhitespace() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedNames = LockIsolated<[String]>([])
    let model = makeModel(onCreate: { _, name in
      capturedNames.withValue { $0.append(name) }
      return ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    })

    model.searchText = "  Tyler Childers  "
    await model.suggestTapped()

    #expect(capturedNames.value == ["Tyler Childers"])
  }

  @Test
  func testSuggestTappedDoesNothingForEmptySearch() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedNames = LockIsolated<[String]>([])
    let model = makeModel(onCreate: { _, name in
      capturedNames.withValue { $0.append(name) }
      return ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    })

    model.searchText = "   "
    await model.suggestTapped()

    #expect(capturedNames.value.isEmpty)
  }

  @Test
  func testSuggestTappedDoesNothingWithoutAuth() async {
    @Shared(.auth) var auth = Auth()
    let capturedNames = LockIsolated<[String]>([])
    let model = makeModel(onCreate: { _, name in
      capturedNames.withValue { $0.append(name) }
      return ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    })

    model.searchText = "Tyler Childers"
    await model.suggestTapped()

    #expect(capturedNames.value.isEmpty)
  }

  @Test
  func testSuggestTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onCreate: { _, _ in
      throw APIError.validationError("Duplicate suggestion")
    })

    model.searchText = "Tyler Childers"
    await model.suggestTapped()

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Error")
    #expect(model.searchText == "Tyler Childers")
  }

  // MARK: - View Helper Tests

  @Test
  func testShowSuggestButtonTrueWhenSearchDoesNotMatchExisting() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "Tyler Childers"

    #expect(model.showSuggestButton)
  }

  @Test
  func testShowSuggestButtonFalseWhenSearchMatchesExistingCaseInsensitive() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "bri bagwell"

    #expect(!model.showSuggestButton)
  }

  @Test
  func testShowSuggestButtonFalseWhenSearchIsEmpty() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = ""

    #expect(!model.showSuggestButton)
  }

  @Test
  func testShowSuggestButtonFalseWhenSearchIsWhitespace() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "   "

    #expect(!model.showSuggestButton)
  }

  @Test
  func testShowEmptyStateTrueWhenNotLoadingAndEmpty() {
    let model = makeModel()
    model.suggestions = []
    model.isLoading = false

    #expect(model.showEmptyState)
  }

  @Test
  func testShowEmptyStateFalseWhenLoading() {
    let model = makeModel()
    model.suggestions = []
    model.isLoading = true

    #expect(!model.showEmptyState)
  }

  @Test
  func testShowEmptyStateFalseWhenSuggestionsExist() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.isLoading = false

    #expect(!model.showEmptyState)
  }

  @Test
  func testEmptyMessageShowsDefaultWhenSearchEmpty() {
    let model = makeModel()
    model.searchText = ""

    #expect(model.emptyMessage == model.emptyStateMessage)
  }

  @Test
  func testEmptyMessageShowsSearchMessageWhenSearchActive() {
    let model = makeModel()
    model.searchText = "Nobody"

    #expect(model.emptyMessage == model.emptySearchMessage)
  }

  @Test
  func testVoteButtonTextShowsVotedWhenHasVoted() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 5, hasVoted: true, createdAt: Date(), updatedAt: Date())

    #expect(model.voteButtonText(suggestion) == "Voted")
  }

  @Test
  func testVoteButtonTextShowsVoteWhenNotVoted() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 5, hasVoted: false, createdAt: Date(), updatedAt: Date())

    #expect(model.voteButtonText(suggestion) == "Vote")
  }

  @Test
  func testVoteCountText() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 42, hasVoted: false, createdAt: Date(), updatedAt: Date())

    #expect(model.voteCountText(suggestion) == "42")
  }

  // MARK: - Double-Tap Guard Tests

  @Test
  func testVoteTappedIgnoredWhileVoteInProgress() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let voteCount = LockIsolated(0)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onVote: { _, _ in
      voteCount.withValue { $0 += 1 }
    })
    model.isVoting = true

    await model.voteTapped(unvotedSuggestion)

    #expect(voteCount.value == 0)
  }

  @Test
  func testSuggestTappedIgnoredWhileSubmitInProgress() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let createCount = LockIsolated(0)
    let model = makeModel(onCreate: { _, name in
      createCount.withValue { $0 += 1 }
      return ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    })
    model.isSubmitting = true
    model.searchText = "Tyler Childers"

    await model.suggestTapped()

    #expect(createCount.value == 0)
  }

  @Test
  func testVoteTappedResetsIsVotingAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())
    let model = makeModel()

    await model.voteTapped(unvotedSuggestion)

    #expect(!model.isVoting)
  }

  @Test
  func testVoteTappedResetsIsVotingAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())
    let model = makeModel(onVote: { _, _ in
      throw APIError.validationError("fail")
    })

    await model.voteTapped(unvotedSuggestion)

    #expect(!model.isVoting)
  }

  @Test
  func testSuggestTappedResetsIsSubmittingAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel()
    model.searchText = "Tyler Childers"

    await model.suggestTapped()

    #expect(!model.isSubmitting)
  }

  @Test
  func testSuggestTappedResetsIsSubmittingAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onCreate: { _, _ in
      throw APIError.validationError("fail")
    })
    model.searchText = "Tyler Childers"

    await model.suggestTapped()

    #expect(!model.isSubmitting)
  }

  // MARK: - Dismiss Tests

  @Test
  func testDismissTappedCallsOnDismiss() {
    let model = makeModel()
    var dismissed = false
    model.onDismiss = { dismissed = true }

    model.dismissTapped()

    #expect(dismissed)
  }

  @Test
  func testDismissTappedDoesNothingWithoutCallback() {
    let model = makeModel()
    model.onDismiss = nil
    model.dismissTapped()
  }
}
