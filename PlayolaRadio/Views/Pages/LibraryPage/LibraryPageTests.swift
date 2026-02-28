//
//  LibraryPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class LibraryPageTests: XCTestCase {
  // MARK: - Initial State Tests

  func testInitialStateLibrarySongsAreEmpty() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertTrue(model.librarySongs.isEmpty)
    }
  }

  func testInitialStateLibraryRequestsAreEmpty() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertTrue(model.libraryRequests.isEmpty)
    }
  }

  func testInitialStateIsNotLoading() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertFalse(model.isLoading)
    }
  }

  func testInitialStateSearchTextIsEmpty() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertEqual(model.searchText, "")
    }
  }

  func testNavigationTitle() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertEqual(model.navigationTitle, "Library")
    }
  }

  // MARK: - View Appeared Tests
  func testViewAppearedFetchesLibrarySongs() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Song One"),
      LibrarySong.mockWith(id: "song-2", title: "Song Two"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      await model.viewAppeared()

      XCTAssertEqual(model.librarySongs.count, 2)
      XCTAssertEqual(model.librarySongs[0].id, "song-1")
      XCTAssertEqual(model.librarySongs[1].id, "song-2")
    }
  }

  func testViewAppearedFetchesLibraryRequests() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", title: "Request One"),
      StationLibraryRequest.mockWith(id: "request-2", title: "Request Two"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in mockRequests }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      await model.viewAppeared()

      XCTAssertEqual(model.libraryRequests.count, 2)
      XCTAssertEqual(model.libraryRequests[0].id, "request-1")
      XCTAssertEqual(model.libraryRequests[1].id, "request-2")
    }
  }

  func testViewAppearedPassesCorrectStationId() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedStationId = LockIsolated<String?>(nil)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { @Sendable _, stationId in
        capturedStationId.withValue { $0 = stationId }
        return .mockWith()
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "my-station-123")

      await model.viewAppeared()

      XCTAssertEqual(capturedStationId.value, "my-station-123")
    }
  }

  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in
        throw APIError.validationError("Failed to fetch library")
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertNil(model.presentedAlert)

      await model.viewAppeared()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
    }
  }

  // MARK: - Search/Filter Tests
  func testFilteredSongsReturnsAllWhenSearchTextIsEmpty() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      model.searchText = ""

      XCTAssertEqual(model.filteredSongs.count, 2)
    }
  }

  func testFilteredSongsFiltersByTitle() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      model.searchText = "Bohemian"

      XCTAssertEqual(model.filteredSongs.count, 1)
      XCTAssertEqual(model.filteredSongs[0].title, "Bohemian Rhapsody")
    }
  }

  func testFilteredSongsFiltersByArtist() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      model.searchText = "Eagles"

      XCTAssertEqual(model.filteredSongs.count, 1)
      XCTAssertEqual(model.filteredSongs[0].artist, "Eagles")
    }
  }

  func testFilteredSongsIsCaseInsensitive() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen")
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      model.searchText = "QUEEN"

      XCTAssertEqual(model.filteredSongs.count, 1)
    }
  }

  // MARK: - Active Requests Tests
  func testActiveRequestsExcludesDismissed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending),
      StationLibraryRequest.mockWith(id: "request-2", status: .completed),
      StationLibraryRequest.mockWith(id: "request-3", status: .dismissed),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in mockRequests }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(model.activeRequests.count, 2)
      XCTAssertTrue(model.activeRequests.contains { $0.id == "request-1" })
      XCTAssertTrue(model.activeRequests.contains { $0.id == "request-2" })
      XCTAssertFalse(model.activeRequests.contains { $0.id == "request-3" })
    }
  }

  // MARK: - Remove Song Tests
  func testRemoveSongButtonTappedCreatesRemoveRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedAudioBlockId = LockIsolated<String?>(nil)
    let mockSong = LibrarySong.mockWith(id: "song-to-remove")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
      $0.api.createRemoveLibraryRequest = { @Sendable _, _, audioBlockId in
        capturedAudioBlockId.withValue { $0 = audioBlockId }
        return .mockWith(type: .remove, audioBlockId: audioBlockId)
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      await model.removeSongButtonTapped(mockSong)

      XCTAssertEqual(capturedAudioBlockId.value, "song-to-remove")
    }
  }

  func testRemoveSongButtonTappedAddsRequestToList() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-to-remove", title: "Song to Remove")
    let mockRequest = StationLibraryRequest.mockWith(
      id: "new-request",
      type: .remove,
      audioBlockId: "song-to-remove",
      title: "Song to Remove"
    )

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
      $0.api.createRemoveLibraryRequest = { _, _, _ in mockRequest }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(model.libraryRequests.count, 0)

      await model.removeSongButtonTapped(mockSong)

      XCTAssertEqual(model.libraryRequests.count, 1)
      XCTAssertEqual(model.libraryRequests[0].id, "new-request")
    }
  }

  // MARK: - Pending Request Check Tests
  func testHasPendingRequestReturnsTrueForSongWithPendingRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .pending,
      audioBlockId: "song-1"
    )

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertTrue(model.hasPendingRequest(for: mockSong))
    }
  }

  func testHasPendingRequestReturnsFalseForSongWithoutRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertFalse(model.hasPendingRequest(for: mockSong))
    }
  }

  // MARK: - Processing Removal Tests

  func testIsProcessingRemovalReturnsFalseInitially() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertFalse(model.isProcessingRemoval(for: mockSong))
    }
  }

  func testIsProcessingRemovalReturnsTrueDuringAPICall() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let isProcessingDuringCall = LockIsolated<Bool?>(nil)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
      $0.api.createRemoveLibraryRequest = { @Sendable [isProcessingDuringCall] _, _, _ in
        await MainActor.run {
          // Can't easily check processing state from inside the mock
          // since we need the model reference
        }
        return .mockWith(type: .remove, audioBlockId: "song-1")
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertFalse(model.isProcessingRemoval(for: mockSong))

      await model.removeSongButtonTapped(mockSong)

      XCTAssertFalse(model.isProcessingRemoval(for: mockSong))
    }
  }

  // MARK: - Dismiss Request Tests

  func testDismissRequestButtonTappedCallsAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedRequestId = LockIsolated<String?>(nil)
    let mockRequest = StationLibraryRequest.mockWith(id: "request-to-dismiss", status: .completed)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
      $0.api.dismissStationLibraryRequest = { @Sendable _, _, requestId in
        capturedRequestId.withValue { $0 = requestId }
        return .mockWith(id: requestId, status: .dismissed)
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      await model.dismissRequestButtonTapped(mockRequest)

      XCTAssertEqual(capturedRequestId.value, "request-to-dismiss")
    }
  }

  func testDismissRequestButtonTappedUpdatesRequestInList() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .completed)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
      $0.api.dismissStationLibraryRequest = { _, _, _ in
        .mockWith(id: "request-1", status: .dismissed)
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(model.activeRequests.count, 1)

      await model.dismissRequestButtonTapped(mockRequest)

      XCTAssertEqual(model.activeRequests.count, 0)
    }
  }

  // MARK: - Refresh Tests

  func testRefreshPulledDownReloadsData() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let fetchCount = LockIsolated(0)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { @Sendable _, _ in
        fetchCount.withValue { $0 += 1 }
        return .mockWith()
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(fetchCount.value, 1)

      await model.refreshPulledDown()

      XCTAssertEqual(fetchCount.value, 2)
    }
  }

  // MARK: - View Helper Tests

  func testSongsSectionHeaderIncludesCount() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1"),
      LibrarySong.mockWith(id: "song-2"),
      LibrarySong.mockWith(id: "song-3"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(model.songsSectionHeader, "SONGS (3)")
    }
  }

  func testSongsSectionHeaderReflectsFilteredCount() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
      LibrarySong.mockWith(id: "song-3", title: "Gamma", artist: "Artist A"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: mockSongs) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      model.searchText = "Artist A"

      XCTAssertEqual(model.songsSectionHeader, "SONGS (2)")
    }
  }

  func testRequestTypeLabelReturnsAddForAddRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(type: .add)

      XCTAssertEqual(model.requestTypeLabel(for: request), "Add")
    }
  }

  func testRequestTypeLabelReturnsRemoveForRemoveRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(type: .remove)

      XCTAssertEqual(model.requestTypeLabel(for: request), "Remove")
    }
  }

  func testRequestTypeColorReturnsSuccessForAddRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(type: .add)

      XCTAssertEqual(model.requestTypeColor(for: request), .success)
    }
  }

  func testRequestTypeColorReturnsWarningForRemoveRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(type: .remove)

      XCTAssertEqual(model.requestTypeColor(for: request), .warning)
    }
  }

  func testRequestStatusLabelReturnsCapitalizedStatus() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      let pendingRequest = StationLibraryRequest.mockWith(status: .pending)
      XCTAssertEqual(model.requestStatusLabel(for: pendingRequest), "Pending")

      let completedRequest = StationLibraryRequest.mockWith(status: .completed)
      XCTAssertEqual(model.requestStatusLabel(for: completedRequest), "Completed")

      let dismissedRequest = StationLibraryRequest.mockWith(status: .dismissed)
      XCTAssertEqual(model.requestStatusLabel(for: dismissedRequest), "Dismissed")
    }
  }

  func testCanDismissRequestReturnsTrueForCompletedRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .completed)

      XCTAssertTrue(model.canDismissRequest(request))
    }
  }

  func testCanDismissRequestReturnsFalseForPendingRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .pending)

      XCTAssertFalse(model.canDismissRequest(request))
    }
  }

  func testCanDismissRequestReturnsFalseForDismissedRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .dismissed)

      XCTAssertFalse(model.canDismissRequest(request))
    }
  }

  func testCanCancelRequestReturnsTrueForPendingRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .pending)

      XCTAssertTrue(model.canCancelRequest(request))
    }
  }

  func testCanCancelRequestReturnsFalseForCompletedRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .completed)

      XCTAssertFalse(model.canCancelRequest(request))
    }
  }

  func testCanCancelRequestReturnsFalseForDismissedRequest() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      let request = StationLibraryRequest.mockWith(status: .dismissed)

      XCTAssertFalse(model.canCancelRequest(request))
    }
  }

  // MARK: - Pending Request Helper Tests

  func testPendingRequestReturnsRequestForSongWithPendingRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      id: "pending-request-1",
      type: .remove,
      status: .pending,
      audioBlockId: "song-1"
    )

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      let result = model.pendingRequest(for: mockSong)
      XCTAssertNotNil(result)
      XCTAssertEqual(result?.id, "pending-request-1")
    }
  }

  func testPendingRequestReturnsNilForSongWithoutPendingRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      let result = model.pendingRequest(for: mockSong)
      XCTAssertNil(result)
    }
  }

  func testPendingRequestReturnsNilForSongWithCompletedRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .completed,
      audioBlockId: "song-1"
    )

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: [mockSong]) }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      let result = model.pendingRequest(for: mockSong)
      XCTAssertNil(result)
    }
  }

  // MARK: - Cancel Request Tests

  func testCancelRequestButtonTappedCallsAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedRequestId = LockIsolated<String?>(nil)
    let mockRequest = StationLibraryRequest.mockWith(id: "request-to-cancel", status: .pending)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
      $0.api.cancelStationLibraryRequest = { @Sendable _, _, requestId in
        capturedRequestId.withValue { $0 = requestId }
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      await model.cancelRequestButtonTapped(mockRequest)

      XCTAssertEqual(capturedRequestId.value, "request-to-cancel")
    }
  }

  func testCancelRequestButtonTappedRemovesRequestFromList() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .pending)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
      $0.api.cancelStationLibraryRequest = { _, _, _ in }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertEqual(model.libraryRequests.count, 1)

      await model.cancelRequestButtonTapped(mockRequest)

      XCTAssertEqual(model.libraryRequests.count, 0)
    }
  }

  func testCancelRequestButtonTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .pending)

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith() }
      $0.api.getStationLibraryRequests = { _, _, _ in [mockRequest] }
      $0.api.cancelStationLibraryRequest = { _, _, _ in
        throw APIError.validationError("Failed to cancel request")
      }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertNil(model.presentedAlert)

      await model.cancelRequestButtonTapped(mockRequest)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
    }
  }

  // MARK: - Add Song Button Tests

  func testAddSongButtonTappedPresentsSongSearchPageSheet() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
      XCTAssertNil(model.songSearchPageModel)

      model.addSongButtonTapped()

      XCTAssertNotNil(model.songSearchPageModel)
      if case .songSearchPage = mainContainerNavigationCoordinator.presentedSheet {
        // Success - presented song search page sheet
      } else {
        XCTFail("Expected songSearchPage sheet presentation")
      }
    }
  }

  func testAddSongButtonTappedUsesSpotifyOnlySearchMode() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      model.addSongButtonTapped()

      XCTAssertEqual(model.songSearchPageModel?.searchMode, .spotifyOnly)
    }
  }

  func testAddSongButtonTappedPassesStationId() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "my-station-456")

      model.addSongButtonTapped()

      XCTAssertEqual(model.songSearchPageModel?.stationId, "my-station-456")
    }
  }

  func testAddSongButtonTappedOnAddedToLibraryCallbackAddsRequestToList() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      model.addSongButtonTapped()

      XCTAssertTrue(model.libraryRequests.isEmpty)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      XCTAssertEqual(model.libraryRequests.count, 1)
      XCTAssertEqual(model.libraryRequests[0].id, "new-add-request")
    }
  }

  func testAddSongButtonTappedOnAddedToLibraryCallbackDismissesSheet() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      model.addSongButtonTapped()

      XCTAssertNotNil(mainContainerNavigationCoordinator.presentedSheet)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
    }
  }

  func testAddSongButtonTappedOnDismissCallbackDismissesSheet() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      model.addSongButtonTapped()

      XCTAssertNotNil(mainContainerNavigationCoordinator.presentedSheet)

      model.songSearchPageModel?.onDismiss?()

      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
    }
  }

  // MARK: - Song Intro Tests

  func testInitialStateSongIdsWithSongIntrosIsEmpty() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    withDependencies {
      $0.date = .constant(Date())
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      XCTAssertTrue(model.songIdsWithSongIntros.isEmpty)
    }
  }

  func testViewAppearedPopulatesSongIdsWithSongIntros() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1"),
      LibrarySong.mockWith(id: "song-2"),
    ]

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in
        .mockWith(songs: mockSongs, songIdsWithSongIntros: ["song-1"])
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")

      await model.viewAppeared()

      XCTAssertEqual(model.songIdsWithSongIntros, Set(["song-1"]))
    }
  }

  func testHasSongIntroReturnsTrueForSongWithIntro() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in
        .mockWith(songs: [mockSong], songIdsWithSongIntros: ["song-1"])
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertTrue(model.hasSongIntro(for: mockSong))
    }
  }

  func testHasSongIntroReturnsFalseForSongWithoutIntro() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in
        .mockWith(songs: [mockSong], songIdsWithSongIntros: [])
      }
      $0.api.getStationLibraryRequests = { _, _, _ in [] }
    } operation: {
      let model = LibraryPageModel(stationId: "test-station")
      await model.viewAppeared()

      XCTAssertFalse(model.hasSongIntro(for: mockSong))
    }
  }

}
