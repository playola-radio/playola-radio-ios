//
//  SongSearchPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Clocks
import ConcurrencyExtras
import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SongSearchPageTests: XCTestCase {
  func testOnCancelTappedCallsOnDismissCallback() {
    var dismissCalled = false

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onDismiss = { dismissCalled = true }

      model.onCancelTapped()

      XCTAssertTrue(dismissCalled)
    }
  }

  func testInitialStateSearchTextIsEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertEqual(model.searchText, "")
    }
  }

  func testInitialStateIsNotSearching() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertFalse(model.isSearching)
    }
  }

  func testInitialStateSearchResultsAreEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertTrue(model.searchResults.isEmpty)
    }
  }

  func testOnSelectSongCallsOnSongSelectedCallback() {
    var selectedSong: AudioBlock?

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      let testAudioBlock = AudioBlock.mockWith(id: "test-song-id", title: "Test Song")
      model.onSongSelected = { selectedSong = $0 }

      model.onSelectSong(testAudioBlock)

      XCTAssertEqual(selectedSong?.id, "test-song-id")
      XCTAssertEqual(selectedSong?.title, "Test Song")
    }
  }

  func testPerformSearchUpdatesSearchResults() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockResults = [
        AudioBlock.mockWith(id: "song-1", title: "First Song"),
        AudioBlock.mockWith(id: "song-2", title: "Second Song"),
      ]

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testPerformSearchClearsResultsWhenQueryIsEmpty() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testPerformSearchShowsAlertOnError() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testPerformSearchShowsAlertWhenNotAuthenticated() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth()

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
      } operation: {
        let model = SongSearchPageModel()
        XCTAssertNil(model.presentedAlert)

        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        XCTAssertNotNil(model.presentedAlert)
        XCTAssertEqual(model.presentedAlert?.title, "Not Signed In")
      }
    }
  }

  func testPerformSearchPassesCorrectKeywordsToAPI() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var capturedKeywords: String?

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testPerformSearchTrimsWhitespace() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var capturedKeywords: String?

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testDebounceOnlySearchesOnceForRapidChanges() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var searchCount = 0

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  func testDebounceDoesNotSearchBeforeDebounceTime() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var searchCount = 0

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
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
  }

  // MARK: - Song Request Tests

  func testInitialStateSongRequestResultsAreEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertTrue(model.songRequestResults.isEmpty)
    }
  }

  func testPerformSearchUpdatesSongRequestResults() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockSongRequests = [
        SongRequest.mockWith(title: "Spotify Song 1", spotifyId: "spotify-1"),
        SongRequest.mockWith(title: "Spotify Song 2", spotifyId: "spotify-2"),
      ]

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in [] }
        $0.api.searchSongRequests = { _, _ in mockSongRequests }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        XCTAssertEqual(model.songRequestResults.count, 2)
        XCTAssertEqual(model.songRequestResults[0].spotifyId, "spotify-1")
        XCTAssertEqual(model.songRequestResults[1].spotifyId, "spotify-2")
      }
    }
  }

  func testPerformSearchSearchesBothSourcesSimultaneously() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var songsSearchCalled = false
      var songRequestsSearchCalled = false

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled = true
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled = true
          return []
        }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        XCTAssertTrue(songsSearchCalled)
        XCTAssertTrue(songRequestsSearchCalled)
      }
    }
  }

  func testPerformSearchClearsSongRequestResultsWhenQueryIsEmpty() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in [] }
        $0.api.searchSongRequests = { _, _ in [SongRequest.mockWith()] }
      } operation: {
        let model = SongSearchPageModel()

        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(model.songRequestResults.count, 1)

        model.searchText = ""
        await clock.advance(by: .milliseconds(300))
        XCTAssertTrue(model.songRequestResults.isEmpty)
      }
    }
  }

  func testOnRequestSongCallsOnSongRequestedCallback() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var requestedSongRequest: SongRequest?

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, _ in }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(
        title: "Test Request", spotifyId: "test-spotify-id")
      model.onSongRequested = { requestedSongRequest = $0 }

      await model.onRequestSong(testSongRequest)

      XCTAssertEqual(requestedSongRequest?.spotifyId, "test-spotify-id")
      XCTAssertEqual(requestedSongRequest?.title, "Test Request")
    }
  }

  func testPerformSearchSongRequestErrorDoesNotAffectSongResults() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockSongs = [AudioBlock.mockWith(id: "song-1")]

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in mockSongs }
        $0.api.searchSongRequests = { _, _ in
          throw APIError.validationError("Spotify search failed")
        }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        XCTAssertEqual(model.searchResults.count, 1)
        XCTAssertTrue(model.songRequestResults.isEmpty)
      }
    }
  }

  // MARK: - SongRequest Status Tests

  func testSongRequestWithNoRequestIdHasUnrequestedStatus() {
    let songRequest = SongRequest.mockWith(requestId: nil)

    XCTAssertEqual(songRequest.requestStatus, .unrequested)
    XCTAssertFalse(songRequest.requestStatus.isRequested)
    XCTAssertNil(songRequest.requestStatus.displayText)
  }

  func testSongRequestWithRequestIdAndCreatedAtHasRequestedStatus() {
    let requestDate = Date(timeIntervalSince1970: 1_000_000)
    let songRequest = SongRequest.mockWith(requestId: "request-123", createdAt: requestDate)

    XCTAssertEqual(songRequest.requestStatus, .requested(requestDate))
    XCTAssertTrue(songRequest.requestStatus.isRequested)
    XCTAssertEqual(songRequest.requestStatus.requestedDate, requestDate)
  }

  func testSongRequestRequestedStatusDisplaysFormattedDate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let components = DateComponents(year: 2025, month: 9, day: 14)
    let requestDate = calendar.date(from: components)!
    let songRequest = SongRequest.mockWith(requestId: "request-123", createdAt: requestDate)

    XCTAssertEqual(songRequest.requestStatus.displayText, "Requested 9/14")
  }

  func testOnRequestSongCallsAPIWithSpotifyId() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var capturedSpotifyId: String?

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, spotifyId in
        capturedSpotifyId = spotifyId
      }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(spotifyId: "test-spotify-123")

      await model.onRequestSong(testSongRequest)

      XCTAssertEqual(capturedSpotifyId, "test-spotify-123")
    }
  }

  func testOnRequestSongUpdatesSongRequestToRequested() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockSongRequests = [
        SongRequest.mockWith(title: "Song 1", spotifyId: "spotify-1"),
        SongRequest.mockWith(title: "Song 2", spotifyId: "spotify-2"),
      ]

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in [] }
        $0.api.searchSongRequests = { _, _ in mockSongRequests }
        $0.api.requestSong = { _, _ in }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        XCTAssertFalse(model.songRequestResults[0].requestStatus.isRequested)

        await model.onRequestSong(model.songRequestResults[0])

        XCTAssertTrue(model.songRequestResults[0].requestStatus.isRequested)
      }
    }
  }

  func testOnRequestSongShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, _ in
        throw APIError.validationError("Request failed")
      }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(spotifyId: "test-spotify-123")

      XCTAssertNil(model.presentedAlert)

      await model.onRequestSong(testSongRequest)

      XCTAssertNotNil(model.presentedAlert)
    }
  }

  // MARK: - Search Mode Tests

  func testDefaultSearchModeIsAll() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertEqual(model.searchMode, .all)
    }
  }

  func testInitWithSearchModeLibraryOnly() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .libraryOnly)

      XCTAssertEqual(model.searchMode, .libraryOnly)
    }
  }

  func testInitWithSearchModeSpotifyOnly() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly)

      XCTAssertEqual(model.searchMode, .spotifyOnly)
    }
  }

  func testLibraryOnlyModeOnlySearchesSongs() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var songsSearchCalled = false
      var songRequestsSearchCalled = false

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled = true
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled = true
          return []
        }
      } operation: {
        let model = SongSearchPageModel(searchMode: .libraryOnly)
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        XCTAssertTrue(songsSearchCalled)
        XCTAssertFalse(songRequestsSearchCalled)
      }
    }
  }

  func testSpotifyOnlyModeOnlySearchesSongRequests() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      var songsSearchCalled = false
      var songRequestsSearchCalled = false

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled = true
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled = true
          return []
        }
      } operation: {
        let model = SongSearchPageModel(searchMode: .spotifyOnly)
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        XCTAssertFalse(songsSearchCalled)
        XCTAssertTrue(songRequestsSearchCalled)
      }
    }
  }

  // MARK: - Library Add Mode Tests

  func testIsLibraryAddModeReturnsFalseByDefault() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertFalse(model.isLibraryAddMode)
    }
  }

  func testIsLibraryAddModeReturnsTrueWhenCallbackSet() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onAddedToLibrary = { _ in }

      XCTAssertTrue(model.isLibraryAddMode)
    }
  }

  func testSpotifySectionHeaderReturnsRequestHeaderByDefault() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      XCTAssertEqual(model.spotifySectionHeader, "AVAILABLE SOON BY REQUEST")
    }
  }

  func testSpotifySectionHeaderReturnsSpotifyHeaderWhenLibraryAddMode() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onAddedToLibrary = { _ in }

      XCTAssertEqual(model.spotifySectionHeader, "SPOTIFY")
    }
  }

  // MARK: - Add Song to Library Tests

  func testOnAddSongToLibraryCallsAPIWithCorrectParameters() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedBody = LockIsolated<CreateAddLibraryRequestBody?>(nil)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { @Sendable _, stationId, body in
        capturedStationId.withValue { $0 = stationId }
        capturedBody.withValue { $0 = body }
        return .mockWith()
      }
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(
        title: "Test Song",
        artist: "Test Artist",
        album: "Test Album",
        spotifyId: "spotify-456",
        imageUrl: URL(string: "https://example.com/image.jpg")
      )

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertEqual(capturedStationId.value, "station-123")
      XCTAssertEqual(capturedBody.value?.spotifyId, "spotify-456")
      XCTAssertEqual(capturedBody.value?.title, "Test Song")
      XCTAssertEqual(capturedBody.value?.artist, "Test Artist")
      XCTAssertEqual(capturedBody.value?.album, "Test Album")
      XCTAssertEqual(capturedBody.value?.imageUrl, "https://example.com/image.jpg")
    }
  }

  func testOnAddSongToLibraryCallsOnAddedToLibraryCallback() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var addedRequest: StationLibraryRequest?
    let mockRequest = StationLibraryRequest.mockWith(id: "new-request", type: .add)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in mockRequest }
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      model.onAddedToLibrary = { addedRequest = $0 }
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertEqual(addedRequest?.id, "new-request")
    }
  }

  func testOnAddSongToLibraryShowsAlertWhenNotAuthenticated() async {
    @Shared(.auth) var auth = Auth()

    await withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      XCTAssertNil(model.presentedAlert)

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Not Signed In")
    }
  }

  func testOnAddSongToLibraryShowsAlertWhenStationIdMissing() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: nil)
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      XCTAssertNil(model.presentedAlert)

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Add Failed")
    }
  }

  func testOnAddSongToLibraryShowsAlertOnAPIError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in
        throw APIError.validationError("Add failed")
      }
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      XCTAssertNil(model.presentedAlert)

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Add Failed")
    }
  }

  // MARK: - Processing Add State Tests

  func testIsProcessingAddReturnsFalseInitially() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      XCTAssertFalse(model.isProcessingAdd(for: testSongRequest))
    }
  }

  func testIsProcessingAddReturnsFalseAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in .mockWith() }
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertFalse(model.isProcessingAdd(for: testSongRequest))
    }
  }

  func testIsProcessingAddReturnsFalseAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in
        throw APIError.validationError("Failed")
      }
    } operation: {
      let model = SongSearchPageModel(searchMode: .spotifyOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(spotifyId: "spotify-456")

      await model.onAddSongToLibrary(testSongRequest)

      XCTAssertFalse(model.isProcessingAdd(for: testSongRequest))
    }
  }
}
