//
//  StationSuggestionPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/10/26.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class StationSuggestionPageTests: XCTestCase {

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
    onGetSuggestions: ((_ jwt: String, _ search: String?) throws -> [ArtistSuggestion])? = nil,
    onCreate: ((_ jwt: String, _ name: String) throws -> ArtistSuggestion)? = nil,
    onVote: ((_ jwt: String, _ id: String) throws -> Void)? = nil,
    onRemoveVote: ((_ jwt: String, _ id: String) throws -> Void)? = nil
  ) -> StationSuggestionPageModel {
    let defaultSuggestions = suggestions ?? mockSuggestions()
    let defaultGet: (String, String?) throws -> [ArtistSuggestion] = { _, _ in defaultSuggestions }
    let defaultCreate: (String, String) throws -> ArtistSuggestion = { _, name in
      ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, createdAt: Date(), updatedAt: Date())
    }
    let defaultVote: (String, String) throws -> Void = { _, _ in }
    let defaultRemoveVote: (String, String) throws -> Void = { _, _ in }
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

  func testViewAppearedFetchesSuggestions() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel()

    await model.viewAppeared()

    XCTAssertEqual(model.suggestions.count, 3)
    XCTAssertEqual(model.suggestions.first?.artistName, "Bri Bagwell")
  }

  func testViewAppearedDoesNothingWithoutAuth() async {
    @Shared(.auth) var auth = Auth()
    let model = makeModel()

    await model.viewAppeared()

    XCTAssertTrue(model.suggestions.isEmpty)
  }

  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onGetSuggestions: { _, _ in
      throw APIError.dataNotValid
    })

    await model.viewAppeared()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Error")
  }

  // MARK: - Search Tests

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
    XCTAssertEqual(searches.last, "Charley")
  }

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
    XCTAssertNil(searches.last ?? nil)
  }

  func testClearSearchTappedResetsTextAndFetches() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let capturedSearches = LockIsolated<[String?]>([])
    let model = makeModel(onGetSuggestions: { _, search in
      capturedSearches.withValue { $0.append(search) }
      return self.mockSuggestions()
    })

    model.searchText = "Charley"
    await model.clearSearchTapped()

    XCTAssertEqual(model.searchText, "")
    XCTAssertNil(capturedSearches.value.last ?? nil)
    XCTAssertEqual(model.suggestions.count, 3)
  }

  // MARK: - Vote Tests

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

    XCTAssertEqual(capturedVoteIds.value, ["s2"])
  }

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

    XCTAssertEqual(capturedRemoveIds.value, ["s1"])
  }

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

    XCTAssertGreaterThanOrEqual(fetchCount.value, 1)
  }

  func testVoteTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())

    let model = makeModel(onVote: { _, _ in
      throw APIError.validationError("Already voted")
    })

    await model.voteTapped(unvotedSuggestion)

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Error")
  }

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

    XCTAssertTrue(capturedVoteIds.value.isEmpty)
  }

  // MARK: - Suggest Tests

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

    XCTAssertEqual(capturedNames.value, ["Tyler Childers"])
    XCTAssertEqual(model.searchText, "")
  }

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

    XCTAssertEqual(capturedNames.value, ["Tyler Childers"])
  }

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

    XCTAssertTrue(capturedNames.value.isEmpty)
  }

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

    XCTAssertTrue(capturedNames.value.isEmpty)
  }

  func testSuggestTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onCreate: { _, _ in
      throw APIError.validationError("Duplicate suggestion")
    })

    model.searchText = "Tyler Childers"
    await model.suggestTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Error")
    XCTAssertEqual(model.searchText, "Tyler Childers")
  }

  // MARK: - View Helper Tests

  func testShowSuggestButtonTrueWhenSearchDoesNotMatchExisting() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "Tyler Childers"

    XCTAssertTrue(model.showSuggestButton)
  }

  func testShowSuggestButtonFalseWhenSearchMatchesExistingCaseInsensitive() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "bri bagwell"

    XCTAssertFalse(model.showSuggestButton)
  }

  func testShowSuggestButtonFalseWhenSearchIsEmpty() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = ""

    XCTAssertFalse(model.showSuggestButton)
  }

  func testShowSuggestButtonFalseWhenSearchIsWhitespace() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.searchText = "   "

    XCTAssertFalse(model.showSuggestButton)
  }

  func testShowEmptyStateTrueWhenNotLoadingAndEmpty() {
    let model = makeModel()
    model.suggestions = []
    model.isLoading = false

    XCTAssertTrue(model.showEmptyState)
  }

  func testShowEmptyStateFalseWhenLoading() {
    let model = makeModel()
    model.suggestions = []
    model.isLoading = true

    XCTAssertFalse(model.showEmptyState)
  }

  func testShowEmptyStateFalseWhenSuggestionsExist() {
    let model = makeModel()
    model.suggestions = mockSuggestions()
    model.isLoading = false

    XCTAssertFalse(model.showEmptyState)
  }

  func testEmptyMessageShowsDefaultWhenSearchEmpty() {
    let model = makeModel()
    model.searchText = ""

    XCTAssertEqual(model.emptyMessage, model.emptyStateMessage)
  }

  func testEmptyMessageShowsSearchMessageWhenSearchActive() {
    let model = makeModel()
    model.searchText = "Nobody"

    XCTAssertEqual(model.emptyMessage, model.emptySearchMessage)
  }

  func testVoteButtonTextShowsVotedWhenHasVoted() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 5, hasVoted: true, createdAt: Date(), updatedAt: Date())

    XCTAssertEqual(model.voteButtonText(suggestion), "Voted")
  }

  func testVoteButtonTextShowsVoteWhenNotVoted() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 5, hasVoted: false, createdAt: Date(), updatedAt: Date())

    XCTAssertEqual(model.voteButtonText(suggestion), "Vote")
  }

  func testVoteCountText() {
    let model = makeModel()
    let suggestion = ArtistSuggestion(
      id: "s1", artistName: "Test", createdByUserId: "u1",
      voteCount: 42, hasVoted: false, createdAt: Date(), updatedAt: Date())

    XCTAssertEqual(model.voteCountText(suggestion), "42")
  }

  // MARK: - Double-Tap Guard Tests

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

    XCTAssertEqual(voteCount.value, 0)
  }

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

    XCTAssertEqual(createCount.value, 0)
  }

  func testVoteTappedResetsIsVotingAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())
    let model = makeModel()

    await model.voteTapped(unvotedSuggestion)

    XCTAssertFalse(model.isVoting)
  }

  func testVoteTappedResetsIsVotingAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let unvotedSuggestion = ArtistSuggestion(
      id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
      voteCount: 7, hasVoted: false, createdAt: Date(), updatedAt: Date())
    let model = makeModel(onVote: { _, _ in
      throw APIError.validationError("fail")
    })

    await model.voteTapped(unvotedSuggestion)

    XCTAssertFalse(model.isVoting)
  }

  func testSuggestTappedResetsIsSubmittingAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel()
    model.searchText = "Tyler Childers"

    await model.suggestTapped()

    XCTAssertFalse(model.isSubmitting)
  }

  func testSuggestTappedResetsIsSubmittingAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: testJwt)
    let model = makeModel(onCreate: { _, _ in
      throw APIError.validationError("fail")
    })
    model.searchText = "Tyler Childers"

    await model.suggestTapped()

    XCTAssertFalse(model.isSubmitting)
  }

  // MARK: - Dismiss Tests

  func testDismissTappedCallsOnDismiss() {
    let model = makeModel()
    var dismissed = false
    model.onDismiss = { dismissed = true }

    model.dismissTapped()

    XCTAssertTrue(dismissed)
  }

  func testDismissTappedDoesNothingWithoutCallback() {
    let model = makeModel()
    model.onDismiss = nil
    model.dismissTapped()
  }
}
