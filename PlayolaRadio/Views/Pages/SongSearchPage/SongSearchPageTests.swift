//
//  SongSearchPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Clocks
import ConcurrencyExtras
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct SongSearchPageTests {
  @Test
  func testOnCancelTappedCallsOnDismissCallback() {
    var dismissCalled = false

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onDismiss = { dismissCalled = true }

      model.onCancelTapped()

      #expect(dismissCalled)
    }
  }

  @Test
  func testInitialStateSearchTextIsEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(model.searchText == "")
    }
  }

  @Test
  func testInitialStateIsNotSearching() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(!model.isSearching)
    }
  }

  @Test
  func testInitialStateSearchResultsAreEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(model.searchResults.isEmpty)
    }
  }

  @Test
  func testOnSelectSongCallsOnSongSelectedCallback() {
    var selectedSong: AudioBlock?

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      let testAudioBlock = AudioBlock.mockWith(id: "test-song-id", title: "Test Song")
      model.onSongSelected = { selectedSong = $0 }

      model.onSelectSong(testAudioBlock)

      #expect(selectedSong?.id == "test-song-id")
      #expect(selectedSong?.title == "Test Song")
    }
  }

  @Test
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

        #expect(model.searchResults.count == 2)
        #expect(model.searchResults[0].id == "song-1")
        #expect(model.searchResults[1].id == "song-2")
      }
    }
  }

  @Test
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
        #expect(model.searchResults.count == 1)

        model.searchText = ""
        await clock.advance(by: .milliseconds(300))
        #expect(model.searchResults.isEmpty)
      }
    }
  }

  @Test
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
        #expect(model.presentedAlert == nil)

        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        #expect(model.presentedAlert != nil)
        #expect(model.presentedAlert?.title == "Search Error")
      }
    }
  }

  @Test
  func testPerformSearchShowsAlertWhenNotAuthenticated() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth()

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
      } operation: {
        let model = SongSearchPageModel()
        #expect(model.presentedAlert == nil)

        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        #expect(model.presentedAlert != nil)
        #expect(model.presentedAlert?.title == "Not Signed In")
      }
    }
  }

  @Test
  func testPerformSearchPassesCorrectKeywordsToAPI() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let capturedKeywords = LockIsolated<String?>(nil)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, keywords in
          capturedKeywords.setValue(keywords)
          return []
        }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "Bob Dylan"

        await clock.advance(by: .milliseconds(300))

        #expect(capturedKeywords.value == "Bob Dylan")
      }
    }
  }

  @Test
  func testPerformSearchTrimsWhitespace() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let capturedKeywords = LockIsolated<String?>(nil)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, keywords in
          capturedKeywords.setValue(keywords)
          return []
        }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "  Bob Dylan  "

        await clock.advance(by: .milliseconds(300))

        #expect(capturedKeywords.value == "Bob Dylan")
      }
    }
  }

  @Test
  func testDebounceOnlySearchesOnceForRapidChanges() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let searchCount = LockIsolated(0)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          searchCount.withValue { $0 += 1 }
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

        #expect(searchCount.value == 1)
      }
    }
  }

  @Test
  func testDebounceDoesNotSearchBeforeDebounceTime() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let searchCount = LockIsolated(0)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          searchCount.withValue { $0 += 1 }
          return []
        }
      } operation: {
        let model = SongSearchPageModel()

        model.searchText = "test"
        await clock.advance(by: .milliseconds(200))

        #expect(searchCount.value == 0)

        await clock.advance(by: .milliseconds(100))

        #expect(searchCount.value == 1)
      }
    }
  }

  // MARK: - Song Request Tests

  @Test
  func testInitialStateSongRequestResultsAreEmpty() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(model.songRequestResults.isEmpty)
    }
  }

  @Test
  func testPerformSearchUpdatesSongRequestResults() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockSongRequests = [
        SongRequest.mockWith(title: "Song Seed 1", appleId: "apple-1"),
        SongRequest.mockWith(title: "Song Seed 2", appleId: "apple-2"),
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

        #expect(model.songRequestResults.count == 2)
        #expect(model.songRequestResults[0].appleId == "apple-1")
        #expect(model.songRequestResults[1].appleId == "apple-2")
      }
    }
  }

  @Test
  func testPerformSearchSearchesBothSourcesSimultaneously() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let songsSearchCalled = LockIsolated(false)
      let songRequestsSearchCalled = LockIsolated(false)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled.setValue(true)
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled.setValue(true)
          return []
        }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        #expect(songsSearchCalled.value)
        #expect(songRequestsSearchCalled.value)
      }
    }
  }

  @Test
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
        #expect(model.songRequestResults.count == 1)

        model.searchText = ""
        await clock.advance(by: .milliseconds(300))
        #expect(model.songRequestResults.isEmpty)
      }
    }
  }

  @Test
  func testOnRequestSongCallsOnSongRequestedCallback() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var requestedSongRequest: SongRequest?

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, _ in }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(
        title: "Test Request", appleId: "test-apple-id")
      model.onSongRequested = { requestedSongRequest = $0 }

      await model.onRequestSong(testSongRequest)

      #expect(requestedSongRequest?.appleId == "test-apple-id")
      #expect(requestedSongRequest?.title == "Test Request")
    }
  }

  @Test
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

        #expect(model.searchResults.count == 1)
        #expect(model.songRequestResults.isEmpty)
      }
    }
  }

  // MARK: - SongRequest Status Tests

  @Test
  func testSongRequestWithNoRequestIdHasUnrequestedStatus() {
    let songRequest = SongRequest.mockWith(requestId: nil)

    #expect(songRequest.requestStatus == .unrequested)
    #expect(!songRequest.requestStatus.isRequested)
    #expect(songRequest.requestStatus.displayText == nil)
  }

  @Test
  func testSongRequestWithRequestIdAndCreatedAtHasRequestedStatus() {
    let requestDate = Date(timeIntervalSince1970: 1_000_000)
    let songRequest = SongRequest.mockWith(requestId: "request-123", createdAt: requestDate)

    #expect(songRequest.requestStatus == .requested(requestDate))
    #expect(songRequest.requestStatus.isRequested)
    #expect(songRequest.requestStatus.requestedDate == requestDate)
  }

  @Test
  func testSongRequestRequestedStatusDisplaysFormattedDate() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let components = DateComponents(year: 2025, month: 9, day: 14)
    let requestDate = calendar.date(from: components)!
    let songRequest = SongRequest.mockWith(requestId: "request-123", createdAt: requestDate)

    #expect(songRequest.requestStatus.displayText == "Requested 9/14")
  }

  @Test
  func testOnRequestSongCallsAPIWithAppleId() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedSongRequest = LockIsolated<SongRequest?>(nil)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, songRequest in
        capturedSongRequest.setValue(songRequest)
      }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(appleId: "test-apple-123")

      await model.onRequestSong(testSongRequest)

      #expect(capturedSongRequest.value?.appleId == "test-apple-123")
    }
  }

  @Test
  func testOnRequestSongUpdatesSongRequestToRequested() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let mockSongRequests = [
        SongRequest.mockWith(title: "Song 1", appleId: "apple-1"),
        SongRequest.mockWith(title: "Song 2", appleId: "apple-2"),
      ]

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.uuid = .incrementing
        $0.api.searchSongs = { _, _ in [] }
        $0.api.searchSongRequests = { _, _ in mockSongRequests }
        $0.api.requestSong = { _, _ in }
      } operation: {
        let model = SongSearchPageModel()
        model.searchText = "test"
        await clock.advance(by: .milliseconds(300))

        #expect(!model.songRequestResults[0].requestStatus.isRequested)

        await model.onRequestSong(model.songRequestResults[0])

        #expect(model.songRequestResults[0].requestStatus.isRequested)
      }
    }
  }

  @Test
  func testOnRequestSongShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.requestSong = { _, _ in
        throw APIError.validationError("Request failed")
      }
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(appleId: "test-apple-123")

      #expect(model.presentedAlert == nil)

      await model.onRequestSong(testSongRequest)

      #expect(model.presentedAlert != nil)
    }
  }

  // MARK: - Search Mode Tests

  @Test
  func testDefaultSearchModeIsAll() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(model.searchMode == .all)
    }
  }

  @Test
  func testInitWithSearchModeLibraryOnly() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .libraryOnly)

      #expect(model.searchMode == .libraryOnly)
    }
  }

  @Test
  func testInitWithSearchModeSeedsOnly() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly)

      #expect(model.searchMode == .seedsOnly)
    }
  }

  @Test
  func testLibraryOnlyModeOnlySearchesSongs() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let songsSearchCalled = LockIsolated(false)
      let songRequestsSearchCalled = LockIsolated(false)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled.setValue(true)
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled.setValue(true)
          return []
        }
      } operation: {
        let model = SongSearchPageModel(searchMode: .libraryOnly)
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        #expect(songsSearchCalled.value)
        #expect(!songRequestsSearchCalled.value)
      }
    }
  }

  @Test
  func testSeedsOnlyModeOnlySearchesSongRequests() async {
    await withMainSerialExecutor {
      let clock = TestClock()
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let songsSearchCalled = LockIsolated(false)
      let songRequestsSearchCalled = LockIsolated(false)

      await withDependencies {
        $0.continuousClock = clock
        $0.date = .constant(Date())
        $0.api.searchSongs = { _, _ in
          songsSearchCalled.setValue(true)
          return []
        }
        $0.api.searchSongRequests = { _, _ in
          songRequestsSearchCalled.setValue(true)
          return []
        }
      } operation: {
        let model = SongSearchPageModel(searchMode: .seedsOnly)
        model.searchText = "test"

        await clock.advance(by: .milliseconds(300))

        #expect(!songsSearchCalled.value)
        #expect(songRequestsSearchCalled.value)
      }
    }
  }

  // MARK: - Library Add Mode Tests

  @Test
  func testIsLibraryAddModeReturnsFalseByDefault() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(!model.isLibraryAddMode)
    }
  }

  @Test
  func testIsLibraryAddModeReturnsTrueWhenCallbackSet() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onAddedToLibrary = { _ in }

      #expect(model.isLibraryAddMode)
    }
  }

  @Test
  func testSongSeedsSectionHeaderReturnsRequestHeaderByDefault() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()

      #expect(model.songSeedsSectionHeader == "AVAILABLE SOON BY REQUEST")
    }
  }

  @Test
  func testSongSeedsSectionHeaderReturnsAppleMusicHeaderWhenLibraryAddMode() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      model.onAddedToLibrary = { _ in }

      #expect(model.songSeedsSectionHeader == "APPLE MUSIC")
    }
  }

  // MARK: - Add Song to Library Tests

  @Test
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
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(
        title: "Test Song",
        artist: "Test Artist",
        album: "Test Album",
        appleId: "apple-456",
        imageUrl: URL(string: "https://example.com/image.jpg")
      )

      await model.onAddSongToLibrary(testSongRequest)

      #expect(capturedStationId.value == "station-123")
      #expect(capturedBody.value?.appleId == "apple-456")
      #expect(capturedBody.value?.title == "Test Song")
      #expect(capturedBody.value?.artist == "Test Artist")
      #expect(capturedBody.value?.album == "Test Album")
      #expect(capturedBody.value?.imageUrl == "https://example.com/image.jpg")
    }
  }

  @Test
  func testOnAddSongToLibraryCallsOnAddedToLibraryCallback() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var addedRequest: StationLibraryRequest?
    let mockRequest = StationLibraryRequest.mockWith(id: "new-request", type: .add)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in mockRequest }
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      model.onAddedToLibrary = { addedRequest = $0 }
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      await model.onAddSongToLibrary(testSongRequest)

      #expect(addedRequest?.id == "new-request")
    }
  }

  @Test
  func testOnAddSongToLibraryShowsAlertWhenNotAuthenticated() async {
    @Shared(.auth) var auth = Auth()

    await withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      #expect(model.presentedAlert == nil)

      await model.onAddSongToLibrary(testSongRequest)

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Not Signed In")
    }
  }

  @Test
  func testOnAddSongToLibraryShowsAlertWhenStationIdMissing() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: nil)
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      #expect(model.presentedAlert == nil)

      await model.onAddSongToLibrary(testSongRequest)

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Add Failed")
    }
  }

  @Test
  func testOnAddSongToLibraryShowsAlertOnAPIError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in
        throw APIError.validationError("Add failed")
      }
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      #expect(model.presentedAlert == nil)

      await model.onAddSongToLibrary(testSongRequest)

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Add Failed")
    }
  }

  // MARK: - Processing Add State Tests

  @Test
  func testIsProcessingAddReturnsFalseInitially() {
    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = SongSearchPageModel()
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      #expect(!model.isProcessingAdd(for: testSongRequest))
    }
  }

  @Test
  func testIsProcessingAddReturnsFalseAfterCompletion() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in .mockWith() }
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      await model.onAddSongToLibrary(testSongRequest)

      #expect(!model.isProcessingAdd(for: testSongRequest))
    }
  }

  @Test
  func testIsProcessingAddReturnsFalseAfterError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.createAddLibraryRequest = { _, _, _ in
        throw APIError.validationError("Failed")
      }
    } operation: {
      let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: "station-123")
      let testSongRequest = SongRequest.mockWith(appleId: "apple-456")

      await model.onAddSongToLibrary(testSongRequest)

      #expect(!model.isProcessingAdd(for: testSongRequest))
    }
  }
}
