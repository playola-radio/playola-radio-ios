//
//  SongSearchPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Clocks
import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SongSearchPageTests: XCTestCase {
  func testOnCancelTapped_CallsOnDismissCallback() {
    var dismissCalled = false
    let model = SongSearchPageModel()
    model.onDismiss = { dismissCalled = true }

    model.onCancelTapped()

    XCTAssertTrue(dismissCalled)
  }

  func testInitialState_SearchTextIsEmpty() {
    let model = SongSearchPageModel()

    XCTAssertEqual(model.searchText, "")
  }

  func testInitialState_IsNotSearching() {
    let model = SongSearchPageModel()

    XCTAssertFalse(model.isSearching)
  }

  func testInitialState_SearchResultsAreEmpty() {
    let model = SongSearchPageModel()

    XCTAssertTrue(model.searchResults.isEmpty)
  }

  func testOnSelectSong_CallsOnSongSelectedCallback() {
    var selectedSong: AudioBlock?
    let model = SongSearchPageModel()
    let testAudioBlock = AudioBlock.mockWith(id: "test-song-id", title: "Test Song")
    model.onSongSelected = { selectedSong = $0 }

    model.onSelectSong(testAudioBlock)

    XCTAssertEqual(selectedSong?.id, "test-song-id")
    XCTAssertEqual(selectedSong?.title, "Test Song")
  }

  func testPerformSearch_UpdatesSearchResults() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockResults = [
      AudioBlock.mockWith(id: "song-1", title: "First Song"),
      AudioBlock.mockWith(id: "song-2", title: "Second Song"),
    ]

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in mockResults }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "test"

      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(model.searchResults.count, 2)
      XCTAssertEqual(model.searchResults[0].id, "song-1")
      XCTAssertEqual(model.searchResults[1].id, "song-2")
    }
  }

  func testPerformSearch_ClearsResultsWhenQueryIsEmpty() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in [AudioBlock.mockWith()] }
    } operation: {
      let model = SongSearchPageModel()

      model.searchText = "test"
      await clock.advance(by: .milliseconds(300))
      XCTAssertEqual(model.searchResults.count, 1)

      model.searchText = ""
      await clock.advance(by: .milliseconds(300))
      XCTAssertTrue(model.searchResults.isEmpty)
    }
  }

  func testPerformSearch_ShowsAlertOnError() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in
        throw APIError.validationError("Search failed")
      }
    } operation: {
      let model = SongSearchPageModel()
      XCTAssertNil(model.presentedAlert)

      model.searchText = "test"
      await clock.advance(by: .milliseconds(300))

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Search Error")
    }
  }

  func testPerformSearch_ShowsAlertWhenNotAuthenticated() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth()

    await withDependencies {
      $0.continuousClock = clock
    } operation: {
      let model = SongSearchPageModel()
      XCTAssertNil(model.presentedAlert)

      model.searchText = "test"
      await clock.advance(by: .milliseconds(300))

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Not Signed In")
    }
  }

  func testPerformSearch_PassesCorrectKeywordsToAPI() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var capturedKeywords: String?

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, keywords in
        capturedKeywords = keywords
        return []
      }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "Bob Dylan"

      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(capturedKeywords, "Bob Dylan")
    }
  }

  func testPerformSearch_TrimsWhitespace() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var capturedKeywords: String?

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, keywords in
        capturedKeywords = keywords
        return []
      }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "  Bob Dylan  "

      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(capturedKeywords, "Bob Dylan")
    }
  }

  func testDebounce_OnlySearchesOnceForRapidChanges() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var searchCount = 0

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in
        searchCount += 1
        return []
      }
    } operation: {
      let model = SongSearchPageModel()

      model.searchText = "B"
      await clock.advance(by: .milliseconds(100))
      model.searchText = "Bo"
      await clock.advance(by: .milliseconds(100))
      model.searchText = "Bob"
      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(searchCount, 1)
    }
  }

  func testDebounce_DoesNotSearchBeforeDebounceTime() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var searchCount = 0

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in
        searchCount += 1
        return []
      }
    } operation: {
      let model = SongSearchPageModel()

      model.searchText = "test"
      await clock.advance(by: .milliseconds(200))

      XCTAssertEqual(searchCount, 0)

      await clock.advance(by: .milliseconds(100))

      XCTAssertEqual(searchCount, 1)
    }
  }

  // MARK: - Song Seed Tests

  func testInitialState_SongSeedResultsAreEmpty() {
    let model = SongSearchPageModel()

    XCTAssertTrue(model.songSeedResults.isEmpty)
  }

  func testPerformSearch_UpdatesSongSeedResults() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongSeeds = [
      SongSeed.mockWith(title: "Spotify Song 1", spotifyId: "spotify-1"),
      SongSeed.mockWith(title: "Spotify Song 2", spotifyId: "spotify-2"),
    ]

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in [] }
      $0.api.searchSongSeeds = { _, _ in mockSongSeeds }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "test"

      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(model.songSeedResults.count, 2)
      XCTAssertEqual(model.songSeedResults[0].spotifyId, "spotify-1")
      XCTAssertEqual(model.songSeedResults[1].spotifyId, "spotify-2")
    }
  }

  func testPerformSearch_SearchesBothSourcesSimultaneously() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var songsSearchCalled = false
    var songSeedsSearchCalled = false

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in
        songsSearchCalled = true
        return []
      }
      $0.api.searchSongSeeds = { _, _ in
        songSeedsSearchCalled = true
        return []
      }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "test"

      await clock.advance(by: .milliseconds(300))

      XCTAssertTrue(songsSearchCalled)
      XCTAssertTrue(songSeedsSearchCalled)
    }
  }

  func testPerformSearch_ClearsSongSeedResultsWhenQueryIsEmpty() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in [] }
      $0.api.searchSongSeeds = { _, _ in [SongSeed.mockWith()] }
    } operation: {
      let model = SongSearchPageModel()

      model.searchText = "test"
      await clock.advance(by: .milliseconds(300))
      XCTAssertEqual(model.songSeedResults.count, 1)

      model.searchText = ""
      await clock.advance(by: .milliseconds(300))
      XCTAssertTrue(model.songSeedResults.isEmpty)
    }
  }

  func testOnRequestSongSeed_CallsOnSongSeedRequestedCallback() {
    var requestedSongSeed: SongSeed?
    let model = SongSearchPageModel()
    let testSongSeed = SongSeed.mockWith(title: "Test Seed", spotifyId: "test-spotify-id")
    model.onSongSeedRequested = { requestedSongSeed = $0 }

    model.onRequestSongSeed(testSongSeed)

    XCTAssertEqual(requestedSongSeed?.spotifyId, "test-spotify-id")
    XCTAssertEqual(requestedSongSeed?.title, "Test Seed")
  }

  func testPerformSearch_SongSeedErrorDoesNotAffectSongResults() async {
    let clock = TestClock()
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [AudioBlock.mockWith(id: "song-1")]

    await withDependencies {
      $0.continuousClock = clock
      $0.api.searchSongs = { _, _ in mockSongs }
      $0.api.searchSongSeeds = { _, _ in
        throw APIError.validationError("Spotify search failed")
      }
    } operation: {
      let model = SongSearchPageModel()
      model.searchText = "test"

      await clock.advance(by: .milliseconds(300))

      XCTAssertEqual(model.searchResults.count, 1)
      XCTAssertTrue(model.songSeedResults.isEmpty)
    }
  }
}
