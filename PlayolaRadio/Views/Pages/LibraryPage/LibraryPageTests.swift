//
//  LibraryPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct LibraryPageTests {
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

  @Test
  func testInitialStateLibrarySongsAreEmpty() {
    withModel { model in
      #expect(model.librarySongs.isEmpty)
    }
  }

  @Test
  func testInitialStateLibraryRequestsAreEmpty() {
    withModel { model in
      #expect(model.libraryRequests.isEmpty)
    }
  }

  @Test
  func testInitialStateIsNotLoading() {
    withModel { model in
      #expect(!model.isLoading)
    }
  }

  @Test
  func testInitialStateSearchTextIsEmpty() {
    withModel { model in
      #expect(model.searchText == "")
    }
  }

  @Test
  func testNavigationTitle() {
    withModel { model in
      #expect(model.navigationTitle == "Library")
    }
  }

  // MARK: - View Appeared Tests

  @Test
  func testViewAppearedFetchesLibrarySongs() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Song One"),
      LibrarySong.mockWith(id: "song-2", title: "Song Two"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      #expect(model.librarySongs.count == 2)
      #expect(model.librarySongs[0].id == "song-1")
      #expect(model.librarySongs[1].id == "song-2")
    }
  }

  @Test
  func testViewAppearedFetchesLibraryRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", title: "Request One"),
      StationLibraryRequest.mockWith(id: "request-2", title: "Request Two"),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(model.libraryRequests.count == 2)
      #expect(model.libraryRequests[0].id == "request-1")
      #expect(model.libraryRequests[1].id == "request-2")
    }
  }

  @Test
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
        #expect(capturedStationId.value == "my-station-123")
      }
    )
  }

  @Test
  func testViewAppearedShowsAlertOnError() async {
    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { _, _ in
          throw APIError.validationError("Failed to fetch library")
        }
      },
      perform: { model in
        #expect(model.presentedAlert != nil)
        #expect(model.presentedAlert?.title == "Error")
      }
    )
  }

  // MARK: - Search/Filter Tests

  @Test
  func testFilteredSongsReturnsAllWhenSearchTextIsEmpty() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = ""
      #expect(model.filteredSongs.count == 2)
    }
  }

  @Test
  func testFilteredSongsFiltersByTitle() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Bohemian"
      #expect(model.filteredSongs.count == 1)
      #expect(model.filteredSongs[0].title == "Bohemian Rhapsody")
    }
  }

  @Test
  func testFilteredSongsFiltersByArtist() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen"),
      LibrarySong.mockWith(id: "song-2", title: "Hotel California", artist: "Eagles"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Eagles"
      #expect(model.filteredSongs.count == 1)
      #expect(model.filteredSongs[0].artist == "Eagles")
    }
  }

  @Test
  func testFilteredSongsIsCaseInsensitive() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Bohemian Rhapsody", artist: "Queen")
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "QUEEN"
      #expect(model.filteredSongs.count == 1)
    }
  }

  // MARK: - Request Filtering Tests

  @Test
  func testPendingRequestsReturnsOnlyPendingRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending),
      StationLibraryRequest.mockWith(id: "request-2", status: .completed),
      StationLibraryRequest.mockWith(id: "request-3", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(model.pendingRequests.count == 1)
      #expect(model.pendingRequests[0].id == "request-1")
    }
  }

  @Test
  func testFulfilledRequestsReturnsOnlyCompletedRequests() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending),
      StationLibraryRequest.mockWith(id: "request-2", status: .completed),
      StationLibraryRequest.mockWith(id: "request-3", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(model.fulfilledRequests.count == 1)
      #expect(model.fulfilledRequests[0].id == "request-2")
    }
  }

  @Test
  func testHasActiveRequestsReturnsTrueWhenPendingExists() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .pending)
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(model.hasActiveRequests)
    }
  }

  @Test
  func testHasActiveRequestsReturnsTrueWhenFulfilledExists() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .completed)
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(model.hasActiveRequests)
    }
  }

  @Test
  func testHasActiveRequestsReturnsFalseWhenAllDismissed() async {
    let mockRequests = [
      StationLibraryRequest.mockWith(id: "request-1", status: .dismissed),
      StationLibraryRequest.mockWith(id: "request-2", status: .dismissed),
    ]

    await withLoadedModel(requests: mockRequests) { model in
      #expect(!model.hasActiveRequests)
    }
  }

  // MARK: - Remove Song Tests

  @Test
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
        #expect(capturedAudioBlockId.value == "song-to-remove")
      }
    )
  }

  @Test
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
        #expect(model.libraryRequests.count == 0)
        await model.removeSongButtonTapped(mockSong)
        #expect(model.libraryRequests.count == 1)
        #expect(model.libraryRequests[0].id == "new-request")
      }
    )
  }

  // MARK: - Pending Request Check Tests

  @Test
  func testHasPendingRequestReturnsTrueForSongWithPendingRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .pending,
      audioBlockId: "song-1"
    )

    await withLoadedModel(songs: [mockSong], requests: [mockRequest]) { model in
      #expect(model.hasPendingRequest(for: mockSong))
    }
  }

  @Test
  func testHasPendingRequestReturnsFalseForSongWithoutRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      #expect(!model.hasPendingRequest(for: mockSong))
    }
  }

  // MARK: - Processing Removal Tests

  @Test
  func testIsProcessingRemovalReturnsFalseInitially() {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    withModel { model in
      #expect(!model.isProcessingRemoval(for: mockSong))
    }
  }

  @Test
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
        #expect(!model.isProcessingRemoval(for: mockSong))
        await model.removeSongButtonTapped(mockSong)
        #expect(!model.isProcessingRemoval(for: mockSong))
      }
    )
  }

  // MARK: - Dismiss Request Tests

  @Test
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
        #expect(capturedRequestId.value == "request-to-dismiss")
      }
    )
  }

  @Test
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
        #expect(model.fulfilledRequests.count == 1)
        await model.dismissRequestButtonTapped(mockRequest)
        #expect(model.fulfilledRequests.count == 0)
      }
    )
  }

  // MARK: - Refresh Tests

  @Test
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
        #expect(fetchCount.value == 1)
        await model.refreshPulledDown()
        #expect(fetchCount.value == 2)
      }
    )
  }

  // MARK: - View Helper Tests

  @Test
  func testSongsSectionHeaderIncludesCount() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1"),
      LibrarySong.mockWith(id: "song-2"),
      LibrarySong.mockWith(id: "song-3"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      #expect(model.songsSectionHeader == "SONGS (3)")
    }
  }

  @Test
  func testSongsSectionHeaderReflectsFilteredCount() async {
    let mockSongs = [
      LibrarySong.mockWith(id: "song-1", title: "Alpha", artist: "Artist A"),
      LibrarySong.mockWith(id: "song-2", title: "Beta", artist: "Artist B"),
      LibrarySong.mockWith(id: "song-3", title: "Gamma", artist: "Artist A"),
    ]

    await withLoadedModel(songs: mockSongs) { model in
      model.searchText = "Artist A"
      #expect(model.songsSectionHeader == "SONGS (2)")
    }
  }

  @Test
  func testRequestTypeLabelReturnsAddForAddRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .add)
      #expect(model.requestTypeLabel(for: request) == "Add")
    }
  }

  @Test
  func testRequestTypeLabelReturnsRemoveForRemoveRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .remove)
      #expect(model.requestTypeLabel(for: request) == "Remove")
    }
  }

  @Test
  func testRequestTypeColorReturnsSuccessForAddRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .add)
      #expect(model.requestTypeColor(for: request) == .success)
    }
  }

  @Test
  func testRequestTypeColorReturnsWarningForRemoveRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(type: .remove)
      #expect(model.requestTypeColor(for: request) == .warning)
    }
  }

  @Test
  func testRequestStatusLabelReturnsCapitalizedStatus() {
    withModel { model in
      let pendingRequest = StationLibraryRequest.mockWith(status: .pending)
      #expect(model.requestStatusLabel(for: pendingRequest) == "Pending")

      let completedRequest = StationLibraryRequest.mockWith(status: .completed)
      #expect(model.requestStatusLabel(for: completedRequest) == "Completed")

      let dismissedRequest = StationLibraryRequest.mockWith(status: .dismissed)
      #expect(model.requestStatusLabel(for: dismissedRequest) == "Dismissed")
    }
  }

  @Test
  func testCanDismissRequestReturnsTrueForCompletedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .completed)
      #expect(model.canDismissRequest(request))
    }
  }

  @Test
  func testCanDismissRequestReturnsFalseForPendingRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .pending)
      #expect(!model.canDismissRequest(request))
    }
  }

  @Test
  func testCanDismissRequestReturnsFalseForDismissedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .dismissed)
      #expect(!model.canDismissRequest(request))
    }
  }

  @Test
  func testCanCancelRequestReturnsTrueForPendingRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .pending)
      #expect(model.canCancelRequest(request))
    }
  }

  @Test
  func testCanCancelRequestReturnsFalseForCompletedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .completed)
      #expect(!model.canCancelRequest(request))
    }
  }

  @Test
  func testCanCancelRequestReturnsFalseForDismissedRequest() {
    withModel { model in
      let request = StationLibraryRequest.mockWith(status: .dismissed)
      #expect(!model.canCancelRequest(request))
    }
  }

  // MARK: - Pending Request Helper Tests

  @Test
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
      #expect(result != nil)
      #expect(result?.id == "pending-request-1")
    }
  }

  @Test
  func testPendingRequestReturnsNilForSongWithoutPendingRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      let result = model.pendingRequest(for: mockSong)
      #expect(result == nil)
    }
  }

  @Test
  func testPendingRequestReturnsNilForSongWithCompletedRequest() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")
    let mockRequest = StationLibraryRequest.mockWith(
      type: .remove,
      status: .completed,
      audioBlockId: "song-1"
    )

    await withLoadedModel(songs: [mockSong], requests: [mockRequest]) { model in
      let result = model.pendingRequest(for: mockSong)
      #expect(result == nil)
    }
  }

  // MARK: - Cancel Request Tests

  @Test
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
        #expect(capturedRequestId.value == "request-to-cancel")
      }
    )
  }

  @Test
  func testCancelRequestButtonTappedRemovesRequestFromList() async {
    let mockRequest = StationLibraryRequest.mockWith(id: "request-1", status: .pending)

    await withLoadedModel(
      requests: [mockRequest],
      configure: {
        $0.api.cancelStationLibraryRequest = { _, _, _ in }
      },
      perform: { model in
        #expect(model.libraryRequests.count == 1)
        await model.cancelRequestButtonTapped(mockRequest)
        #expect(model.libraryRequests.count == 0)
      }
    )
  }

  @Test
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
        #expect(model.presentedAlert == nil)
        await model.cancelRequestButtonTapped(mockRequest)
        #expect(model.presentedAlert != nil)
        #expect(model.presentedAlert?.title == "Error")
      }
    )
  }

  // MARK: - Add Song Button Tests

  @Test
  func testAddSongButtonTappedPresentsSongSearchPageSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      #expect(mainContainerNavigationCoordinator.presentedSheet == nil)
      #expect(model.songSearchPageModel == nil)

      model.addSongButtonTapped()

      #expect(model.songSearchPageModel != nil)
      if case .songSearchPage = mainContainerNavigationCoordinator.presentedSheet {
        // Success
      } else {
        Issue.record("Expected songSearchPage sheet presentation")
      }
    }
  }

  @Test
  func testAddSongButtonTappedUsesSeedsOnlySearchMode() {
    withModel { model in
      model.addSongButtonTapped()
      #expect(model.songSearchPageModel?.searchMode == .seedsOnly)
    }
  }

  @Test
  func testAddSongButtonTappedPassesStationId() {
    withModel(stationId: "my-station-456") { model in
      model.addSongButtonTapped()
      #expect(model.songSearchPageModel?.stationId == "my-station-456")
    }
  }

  @Test
  func testAddSongButtonTappedOnAddedToLibraryCallbackAddsRequestToList() {
    withModel { model in
      model.addSongButtonTapped()
      #expect(model.libraryRequests.isEmpty)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      #expect(model.libraryRequests.count == 1)
      #expect(model.libraryRequests[0].id == "new-add-request")
    }
  }

  @Test
  func testAddSongButtonTappedOnAddedToLibraryCallbackDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      model.addSongButtonTapped()
      #expect(mainContainerNavigationCoordinator.presentedSheet != nil)

      let mockRequest = StationLibraryRequest.mockWith(id: "new-add-request", type: .add)
      model.songSearchPageModel?.onAddedToLibrary?(mockRequest)

      #expect(mainContainerNavigationCoordinator.presentedSheet == nil)
    }
  }

  @Test
  func testAddSongButtonTappedOnDismissCallbackDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      model.addSongButtonTapped()
      #expect(mainContainerNavigationCoordinator.presentedSheet != nil)

      model.songSearchPageModel?.onDismiss?()

      #expect(mainContainerNavigationCoordinator.presentedSheet == nil)
    }
  }

  // MARK: - Song Intro Tests

  @Test
  func testInitialStateSongIdsWithSongIntrosIsEmpty() {
    withModel { model in
      #expect(model.songIdsWithSongIntros.isEmpty)
    }
  }

  @Test
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
        #expect(model.songIdsWithSongIntros == Set(["song-1"]))
      }
    )
  }

  @Test
  func testHasSongIntroReturnsTrueForSongWithIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(
      configure: {
        $0.api.getStationLibrary = { _, _ in
          .mockWith(songs: [mockSong], songIdsWithSongIntros: ["song-1"])
        }
      },
      perform: { model in
        #expect(model.hasSongIntro(for: mockSong))
      }
    )
  }

  @Test
  func testHasSongIntroReturnsFalseForSongWithoutIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      #expect(!model.hasSongIntro(for: mockSong))
    }
  }

  // MARK: - Intro Upload Tests

  @Test
  func testRecordIntroButtonTappedPresentsRecordIntroSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    withModel { model in
      let song = LibrarySong.mockWith(id: "song-1", title: "Test Song", artist: "Test Artist")

      model.recordIntroButtonTapped(song)

      if case .recordIntroPage = mainContainerNavigationCoordinator.presentedSheet {
        // Success
      } else {
        Issue.record("Expected recordIntroPage sheet")
      }
    }
  }

  @Test
  func testHasSongIntroReturnsTrueForLocallyUploadedIntro() async {
    let mockSong = LibrarySong.mockWith(id: "song-1")

    await withLoadedModel(songs: [mockSong]) { model in
      #expect(!model.hasSongIntro(for: mockSong))
      model.uploadedIntroSongIds.insert("song-1")
      #expect(model.hasSongIntro(for: mockSong))
    }
  }
}
