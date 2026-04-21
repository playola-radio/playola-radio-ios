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
  // MARK: - Helpers

  private func withModel(
    stationId: String = "test-station",
    configure: ((inout DependencyValues) -> Void)? = nil,
    perform: (LibraryPageModel) -> Void
  ) {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    withDependencies {
      $0.date = .constant(Date())
      configure?(&$0)
    } operation: {
      perform(LibraryPageModel(stationId: stationId))
    }
  }

  private func withLoadedModel(
    stationId: String = "test-station",
    songs: [LibrarySong] = [],
    requests: [StationLibraryRequest] = [],
    configure: ((inout DependencyValues) -> Void)? = nil,
    perform: (LibraryPageModel) async -> Void
  ) async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    await withDependencies {
      $0.date = .constant(Date())
      $0.api.getStationLibrary = { _, _ in .mockWith(songs: songs) }
      $0.api.getStationLibraryRequests = { _, _, _ in requests }
      configure?(&$0)
    } operation: {
      let model = LibraryPageModel(stationId: stationId)
      await model.viewAppeared()
      await perform(model)
    }
  }

  // MARK: - Initial State Tests

  func testInitialStateLibrarySongsAreEmpty() {
    withModel { model in
      XCTAssertTrue(model.librarySongs.isEmpty)
    }
  }

  func testInitialStateLibraryRequestsAreEmpty() {
    withModel { model in
      XCTAssertTrue(model.libraryRequests.isEmpty)
    }
  }

  func testInitialStateIsNotLoading() {
    withModel { model in
      XCTAssertFalse(model.isLoading)
    }
  }

  func testInitialStateSearchTextIsEmpty() {
    withModel { model in
      XCTAssertEqual(model.searchText, "")
    }
  }

  func testNavigationTitle() {
    withModel { model in
      XCTAssertEqual(model.navigationTitle, "Library")
    }
  }

  // MARK: - View Appeared Tests

  func testViewAppearedFetchesLibrarySongs() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Song One"),
      LibrarySong.mockWith(id: "song-2", title: "Song Two"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      XCTAssertEqual(model.librarySongs.count, 2)
      XCTAssertEqual(model.librarySongs[0].id, "song-1")
      XCTAssertEqual(model.librarySongs[1].id, "song-2")
    }
  }

  func testViewAppearedFetchesLibraryRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", title: "Request One"),
      StationLibraryRequest.mockWith(id: "request-2", title: "Request Two"),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertEqual(model.libraryRequests.count, 2)
      XCTAssertEqual(model.libraryRequests[0].id, "request-1")
      XCTAssertEqual(model.libraryRequests[1].id, "request-2")
    }
  }

  func testViewAppearedPassesCorrectStationId() async {
    let capturedStationId = LockIsolated<String?>(nil)

    await withLoadedModel(
      stationId: "my-station-123",
      configure: {
        $0.api.getStationLibrary = { @Sendable _, stationId in
          capturedStationId.withValue { $0 = stationId }
          return .mockWith()
        }
      },
      perform: { _ in
        XCTAssertEqual(capturedStationId.value, "my-station-123")
      }
    )
  }

  func testViewAppearedShowsAlertOnError() async {
    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { _, _ in
          throw APIError.validationError("Failed to fetch library")
        }
      },
      perform: { model in
        XCTAssertNotNil(model.presentedAlert)
        XCTAssertEqual(model.presentedAlert?.title, "Error")
      }
    )
  }

  // MARK: - Search/Filter Tests

  func testFilteredSongsReturnsAllWhenSearchTextIsEmpty() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = ""
      XCTAssertEqual(model.filteredSongs.count, 2)
    }
  }

  func testFilteredSongsFiltersByTitle() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Bohemian"
      XCTAssertEqual(model.filteredSongs.count, 1)
      XCTAssertEqual(model.filteredSongs[0].title, "Bohemian Rhapsody")
    }
  }

  func testFilteredSongsFiltersByArtist() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Eagles"
      XCTAssertEqual(model.filteredSongs.count, 1)
      XCTAssertEqual(model.filteredSongs[0].artist, "Eagles")
    }
  }

  func testFilteredSongsIsCaseInsensitive() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen")
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "QUEEN"
      XCTAssertEqual(model.filteredSongs.count, 1)
    }
  }

  // MARK: - Request Filtering Tests

  func testPendingRequestsReturnsOnlyPendingRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending),
      StationLibraryRequest.mockWith(id: "request-2", status: .completed),
      StationLibraryRequest.mockWith(id: "request-3", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertEqual(model.pendingRequests.count, 1)
      XCTAssertEqual(model.pendingRequests[0].id, "request-1")
    }
  }

  func testFulfilledRequestsReturnsOnlyCompletedRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending),
      StationLibraryRequest.mockWith(id: "request-2", status: .completed),
      StationLibraryRequest.mockWith(id: "request-3", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertEqual(model.fulfilledRequests.count, 1)
      XCTAssertEqual(model.fulfilledRequests[0].id, "request-2")
    }
  }

  func testHasActiveRequestsReturnsTrueWhenPendingExists() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending)
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertTrue(model.hasActiveRequests)
    }
  }

  func testHasActiveRequestsReturnsTrueWhenFulfilledExists() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .completed)
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertTrue(model.hasActiveRequests)
    }
  }

  func testHasActiveRequestsReturnsFalseWhenAllDismissed() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .dismissed),
      StationLibraryRequest.mockWith(id: "request-2", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      XCTAssertFalse(model.hasActiveRequests)
    }
  }

  // MARK: - Remove Song Tests

  func testRemoveSongButtonTappedCreatesRemoveRequest() async {
    let capturedAudioBlockId = LockIsolated<String?>(nil)
    let mockSong = LibrarySong.mockWith(id: "song-to-remove")

    await withLoadedModel(
      songs: [mockSong],
      configure: {
        $0.api.createRemoveLibraryRequest = { @Sendable _, _, audioBlockId in
          capturedAudioBlockId.withValue { $0 = audioBlockId }
          return .mockWith(type: .remove, audioBlockId: audioBlockId)
        }
      },
      perform: { model in
        await model.removeSongButtonTapped(mockSong)
        XCTAssertEqual(capturedAudioBlockId.value, "song-to-remove")
      }
    )
  }

  func testRemoveSongButtonTappedAddsRequestToList() async {
    let mockSong = LibrarySong.mockWith(id: "song-to-remove", title: "Song to Remove")
    let mockRequest = StationLibraryRequest.mockWith(
      id: "new-request",
      type: .remove,
      audioBlockId: "song-to-remove",
      title: "Song to Remove"
    )

    await withLoadedModel(
      songs: [mockSong],
      configure: {
        $0.api.createRemoveLibraryRequest = { _, _, _ in mockRequest }
      },
      perform: { model in
        XCTAssertEqual(model.libraryRequests.count, 0)
        await model.removeSongButtonTapped(mockSong)
        XCTAssertEqual(model.libraryRequests.count, 1)
        XCTAssertEqual(model.libraryRequests[0].id, "new-request")
      }
    )
  }

  // MARK: - Pending Request Check Tests

  func testHasPendingRequestReturnsTrueForSongWithPendingRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .pending,
      audioBlockId: "song-1"
    )

    await withLoadedModel(songs: [mockSong], requests: [mockRequest]) { model in
      XCTAssertTrue(model.hasPendingRequest(for: mockSong))
    }
  }

  func testHasPendingRequestReturnsFalseForSongWithoutRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      XCTAssertFalse(model.hasPendingRequest(for: mockSong))
    }
  }

  // MARK: - Processing Removal Tests

  func testIsProcessingRemovalReturnsFalseInitially() {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    withModel { model in
      XCTAssertFalse(model.isProcessingRemoval(for: mockSong))
    }
  }

  func testIsProcessingRemovalReturnsFalseAfterCompletion() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(
      songs: [mockSong],
      configure: {
        $0.api.createRemoveLibraryRequest = { @Sendable _, _, _ in
          .mockWith(type: .remove, audioBlockId: "song-1")
        }
      },
      perform: { model in
        XCTAssertFalse(model.isProcessingRemoval(for: mockSong))
        await model.removeSongButtonTapped(mockSong)
        XCTAssertFalse(model.isProcessingRemoval(for: mockSong))
      }
    )
  }

  // MARK: - Dismiss Request Tests

  func testDismissRequestButtonTappedCallsAPI() async {
    let capturedRequestId = LockIsolated<String?>(nil)
    let mockRequest = StationLibraryRequest.mockWith(id: "request-to-dismiss", status: .completed)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.dismissStationLibraryRequest = { @Sendable _, _, requestId in
          capturedRequestId.withValue { $0 = requestId }
          return .mockWith(id: requestId, status: .dismissed)
        }
      },
      perform: { model in
        await model.dismissRequestButtonTapped(mockRequest)
        XCTAssertEqual(capturedRequestId.value, "request-to-dismiss")
      }
    )
  }

  func testDismissRequestButtonTappedUpdatesRequestInList() async {
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .completed)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.dismissStationLibraryRequest = { _, _, _ in
          .mockWith(id: "request-1", status: .dismissed)
        }
      },
      perform: { model in
        XCTAssertEqual(model.fulfilledRequests.count, 1)
        await model.dismissRequestButtonTapped(mockRequest)
        XCTAssertEqual(model.fulfilledRequests.count, 0)
      }
    )
  }

  // MARK: - Refresh Tests

  func testRefreshPulledDownReloadsData() async {
    let fetchCount = LockIsolated(0)

    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { @Sendable _, _ in
          fetchCount.withValue { $0 += 1 }
          return .mockWith()
        }
      },
      perform: { model in
        XCTAssertEqual(fetchCount.value, 1)
        await model.refreshPulledDown()
        XCTAssertEqual(fetchCount.value, 2)
      }
    )
  }

  // MARK: - View Helper Tests

  func testSongsSectionHeaderIncludesCount() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1"),
      LibrarySong.mockWith(id: "song-2"),
      LibrarySong.mockWith(id: "song-3"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      XCTAssertEqual(model.songsSectionHeader, "SONGS (3)")
    }
  }

  func testSongsSectionHeaderReflectsFilteredCount() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
      LibrarySong.mockWith(id: "song-3", title: "Gamma", artist: "Artist A"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Artist A"
      XCTAssertEqual(model.songsSectionHeader, "SONGS (2)")
    }
  }

  func testRequestTypeLabelReturnsAddForAddRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .add)
      XCTAssertEqual(model.requestTypeLabel(for: request), "Add")
    }
  }

  func testRequestTypeLabelReturnsRemoveForRemoveRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .remove)
      XCTAssertEqual(model.requestTypeLabel(for: request), "Remove")
    }
  }

  func testRequestTypeColorReturnsSuccessForAddRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .add)
      XCTAssertEqual(model.requestTypeColor(for: request), .success)
    }
  }

  func testRequestTypeColorReturnsWarningForRemoveRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .remove)
      XCTAssertEqual(model.requestTypeColor(for: request), .warning)
    }
  }

  func testRequestStatusLabelReturnsCapitalizedStatus() {
    withModel { model in
      let pendingRequest = StationLibraryRequest.mockWith(status: .pending)
      XCTAssertEqual(model.requestStatusLabel(for: pendingRequest), "Pending")

      let completedRequest = StationLibraryRequest.mockWith(status: .completed)
      XCTAssertEqual(model.requestStatusLabel(for: completedRequest), "Completed")

      let dismissedRequest = StationLibraryRequest.mockWith(status: .dismissed)
      XCTAssertEqual(model.requestStatusLabel(for: dismissedRequest), "Dismissed")
    }
  }

  func testCanDismissRequestReturnsTrueForCompletedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .completed)
      XCTAssertTrue(model.canDismissRequest(request))
    }
  }

  func testCanDismissRequestReturnsFalseForPendingRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .pending)
      XCTAssertFalse(model.canDismissRequest(request))
    }
  }

  func testCanDismissRequestReturnsFalseForDismissedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .dismissed)
      XCTAssertFalse(model.canDismissRequest(request))
    }
  }

  func testCanCancelRequestReturnsTrueForPendingRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .pending)
      XCTAssertTrue(model.canCancelRequest(request))
    }
  }

  func testCanCancelRequestReturnsFalseForCompletedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .completed)
      XCTAssertFalse(model.canCancelRequest(request))
    }
  }

  func testCanCancelRequestReturnsFalseForDismissedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .dismissed)
      XCTAssertFalse(model.canCancelRequest(request))
    }
  }

  // MARK: - Pending Request Helper Tests

  func testPendingRequestReturnsRequestForSongWithPendingRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      id: "pending-request-1",
      type: .remove,
      status: .pending,
      audioBlockId: "song-1"
    )

    await withLoadedModel(songs: [mockSong], requests: [mockRequest]) { model in
      let result = model.pendingRequest(for: mockSong)
      XCTAssertNotNil(result)
      XCTAssertEqual(result?.id, "pending-request-1")
    }
  }

  func testPendingRequestReturnsNilForSongWithoutPendingRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      let result = model.pendingRequest(for: mockSong)
      XCTAssertNil(result)
    }
  }

  func testPendingRequestReturnsNilForSongWithCompletedRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .completed,
      audioBlockId: "song-1"
    )

    await withLoadedModel(songs: [mockSong], requests: [mockRequest]) { model in
      let result = model.pendingRequest(for: mockSong)
      XCTAssertNil(result)
    }
  }

  // MARK: - Cancel Request Tests

  func testCancelRequestButtonTappedCallsAPI() async {
    let capturedRequestId = LockIsolated<String?>(nil)
    let mockRequest = StationLibraryRequest.mockWith(id: "request-to-cancel", status: .pending)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.cancelStationLibraryRequest = { @Sendable _, _, requestId in
          capturedRequestId.withValue { $0 = requestId }
        }
      },
      perform: { model in
        await model.cancelRequestButtonTapped(mockRequest)
        XCTAssertEqual(capturedRequestId.value, "request-to-cancel")
      }
    )
  }

  func testCancelRequestButtonTappedRemovesRequestFromList() async {
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .pending)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.cancelStationLibraryRequest = { _, _, _ in }
      },
      perform: { model in
        XCTAssertEqual(model.libraryRequests.count, 1)
        await model.cancelRequestButtonTapped(mockRequest)
        XCTAssertEqual(model.libraryRequests.count, 0)
      }
    )
  }

  func testCancelRequestButtonTappedShowsAlertOnError() async {
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .pending)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.cancelStationLibraryRequest = { _, _, _ in
          throw APIError.validationError("Failed to cancel request")
        }
      },
      perform: { model in
        XCTAssertNil(model.presentedAlert)
        await model.cancelRequestButtonTapped(mockRequest)
        XCTAssertNotNil(model.presentedAlert)
        XCTAssertEqual(model.presentedAlert?.title, "Error")
      }
    )
  }

  // MARK: - Add Song Button Tests

  func testAddSongButtonTappedPresentsSongSearchPageSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
      XCTAssertNil(model.songSearchPageModel)

      model.addSongButtonTapped()

      XCTAssertNotNil(model.songSearchPageModel)
      if case .songSearchPage = mainContainerNavigationCoordinator.presentedSheet {
        // Success
      } else {
        XCTFail("Expected songSearchPage sheet presentation")
      }
    }
  }

  func testAddSongButtonTappedUsesSeedsOnlySearchMode() {
    withModel { model in
      model.addSongButtonTapped()
      XCTAssertEqual(model.songSearchPageModel?.searchMode, .seedsOnly)
    }
  }

  func testAddSongButtonTappedPassesStationId() {
    withModel(stationId: "my-station-456") { model in
      model.addSongButtonTapped()
      XCTAssertEqual(model.songSearchPageModel?.stationId, "my-station-456")
    }
  }

  func testAddSongButtonTappedOnAddedToLibraryCallbackAddsRequestToList() {
    withModel { model in
      model.addSongButtonTapped()
      XCTAssertTrue(model.libraryRequests.isEmpty)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      XCTAssertEqual(model.libraryRequests.count, 1)
      XCTAssertEqual(model.libraryRequests[0].id, "new-add-request")
    }
  }

  func testAddSongButtonTappedOnAddedToLibraryCallbackDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      model.addSongButtonTapped()
      XCTAssertNotNil(mainContainerNavigationCoordinator.presentedSheet)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
    }
  }

  func testAddSongButtonTappedOnDismissCallbackDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      model.addSongButtonTapped()
      XCTAssertNotNil(mainContainerNavigationCoordinator.presentedSheet)

      model.songSearchPageModel?.onDismiss?()

      XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
    }
  }

  // MARK: - Song Intro Tests

  func testInitialStateSongIdsWithSongIntrosIsEmpty() {
    withModel { model in
      XCTAssertTrue(model.songIdsWithSongIntros.isEmpty)
    }
  }

  func testViewAppearedPopulatesSongIdsWithSongIntros() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1"),
      LibrarySong.mockWith(id: "song-2"),
    ]

    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { _, _ in
          .mockWith(songs: mockSongs, songIdsWithSongIntros: ["song-1"])
        }
      },
      perform: { model in
        XCTAssertEqual(model.songIdsWithSongIntros, Set(["song-1"]))
      }
    )
  }

  func testHasSongIntroReturnsTrueForSongWithIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { _, _ in
          .mockWith(songs: [mockSong], songIdsWithSongIntros: ["song-1"])
        }
      },
      perform: { model in
        XCTAssertTrue(model.hasSongIntro(for: mockSong))
      }
    )
  }

  func testHasSongIntroReturnsFalseForSongWithoutIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      XCTAssertFalse(model.hasSongIntro(for: mockSong))
    }
  }

  // MARK: - Intro Upload Tests

  func testRecordIntroButtonTappedPresentsRecordIntroSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      let song = LibrarySong.mockWith(id: "song-1", title: "Test Song", artist: "Test Artist")

      model.recordIntroButtonTapped(song)

      if case .recordIntroPage = mainContainerNavigationCoordinator.presentedSheet {
        // Success
      } else {
        XCTFail("Expected recordIntroPage sheet")
      }
    }
  }

  func testHasSongIntroReturnsTrueForLocallyUploadedIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      XCTAssertFalse(model.hasSongIntro(for: mockSong))
      model.uploadedIntroSongIds.insert("song-1")
      XCTAssertTrue(model.hasSongIntro(for: mockSong))
    }
  }
}
