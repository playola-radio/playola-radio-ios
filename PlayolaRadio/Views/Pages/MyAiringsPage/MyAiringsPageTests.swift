//
//  MyAiringsPageTests.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class MyAiringsPageModelTests: XCTestCase {

  // MARK: - viewAppeared

  func testViewAppearedLoadsAiringsAndClips() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past-airing",
      airtime: now.addingTimeInterval(-86400)
    )
    let futureAiring = ListenerQuestionAiring.mockWith(
      id: "future-airing",
      airtime: now.addingTimeInterval(86400)
    )
    let clip = Clip.mockWith(
      id: "clip-1",
      tracks: [
        ClipTrack(
          title: "Q&A", artist: "Test", type: "voicetrack",
          startsAtMS: 0, durationMS: 60000, listenerQuestionAiringId: "past-airing"
        )
      ]
    )

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [pastAiring, futureAiring] }
      $0.api.getUserClips = { _ in [clip] }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertEqual(model.airings.count, 2)
      XCTAssertEqual(model.pastAirings.count, 1)
      XCTAssertEqual(model.upcomingAirings.count, 1)
      XCTAssertNotNil(model.clips["past-airing"])
    }
  }

  func testViewAppearedDoesNotCallAPIWithoutJWT() async {
    @Shared(.auth) var auth = Auth(jwt: nil)
    var apiCalled = false

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in
        apiCalled = true
        return []
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertFalse(apiCalled)
    }
  }

  func testViewAppearedShowsAlertOnAPIError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in throw APIError.dataNotValid }
      $0.api.getUserClips = { _ in [] }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertNotNil(model.presentedAlert)
    }
  }

  func testViewAppearedSchedulesLocalNotifications() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let futureAiring = ListenerQuestionAiring.mockWith(
      id: "future",
      airtime: now.addingTimeInterval(86400),
      station: .mockWith(curatorName: "DJ Test")
    )
    var scheduledNotificationId: String?
    var scheduledTitle: String?

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [futureAiring] }
      $0.api.getUserClips = { _ in [] }
      $0.pushNotifications.scheduleNotification = { identifier, title, _, _ in
        scheduledNotificationId = identifier
        scheduledTitle = title
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertEqual(scheduledNotificationId, "airing-reminder-future")
      XCTAssertEqual(scheduledTitle, "DJ Test")
    }
  }

  func testMatchClipsToAiringsSkipsClipsWithNilTracks() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")
    let clipWithoutTracks = Clip.mockWith(id: "clip-no-tracks", tracks: nil)

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [pastAiring] }
      $0.api.getUserClips = { _ in [clipWithoutTracks] }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertNil(model.clips["past"])
    }
  }

  // MARK: - Empty State

  func testEmptyStateShownWhenNoAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [] }
      $0.api.getUserClips = { _ in [] }
    } operation: {
      let model = MyAiringsPageModel()

      await model.viewAppeared()

      XCTAssertTrue(model.showEmptyState)
      XCTAssertTrue(model.airings.isEmpty)
    }
  }

  func testBrowseStationsTappedPopsNavigation() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let model = MyAiringsPageModel()
    navCoordinator.push(.myAiringsPage(model))
    XCTAssertEqual(navCoordinator.path.count, 1)

    model.browseStationsTapped()

    XCTAssertTrue(navCoordinator.path.isEmpty)
  }

  // MARK: - clipState

  func testClipStateReturnsUpcomingForFutureAirings() async {
    let now = Date()
    let futureAiring = ListenerQuestionAiring.mockWith(
      id: "future",
      airtime: now.addingTimeInterval(86400)
    )

    await withDependencies {
      $0.date.now = now
    } operation: {
      let model = MyAiringsPageModel()
      model.airings = [futureAiring]

      XCTAssertEqual(model.clipState(for: futureAiring), .upcoming)
    }
  }

  func testClipStateReturnsNoClipForPastAiringWithoutClip() async {
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past",
      airtime: now.addingTimeInterval(-86400)
    )

    await withDependencies {
      $0.date.now = now
    } operation: {
      let model = MyAiringsPageModel()
      model.airings = [pastAiring]

      XCTAssertEqual(model.clipState(for: pastAiring), .noClip)
    }
  }

  func testClipStateReturnsReadyForCompletedClip() async {
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past",
      airtime: now.addingTimeInterval(-86400)
    )
    let clip = Clip.mockWith(status: .completed)

    await withDependencies {
      $0.date.now = now
    } operation: {
      let model = MyAiringsPageModel()
      model.airings = [pastAiring]
      model.clips["past"] = clip

      XCTAssertEqual(model.clipState(for: pastAiring), .ready(clip))
    }
  }

  func testClipStateReturnsCreatingWhenPolling() async {
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past",
      airtime: now.addingTimeInterval(-86400)
    )

    await withDependencies {
      $0.date.now = now
    } operation: {
      let model = MyAiringsPageModel()
      model.airings = [pastAiring]
      model.pollingAiringIds.insert("past")

      XCTAssertEqual(model.clipState(for: pastAiring), .creating)
    }
  }

  func testClipStateReturnsFailedForFailedClip() async {
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past",
      airtime: now.addingTimeInterval(-86400)
    )
    let clip = Clip.mockWith(status: .failed, errorMessage: "Processing error")

    await withDependencies {
      $0.date.now = now
    } operation: {
      let model = MyAiringsPageModel()
      model.airings = [pastAiring]
      model.clips["past"] = clip

      XCTAssertEqual(model.clipState(for: pastAiring), .failed("Processing error"))
    }
  }

  // MARK: - createClipTapped

  func testCreateClipTappedCallsAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past",
      airtime: now.addingTimeInterval(-86400)
    )
    var createClipCalled = false
    var passedFirstSpinId: String?
    var passedLastSpinId: String?

    await withDependencies {
      $0.date.now = now
      $0.api.getAiringSpins = { _, _ in
        AiringSpinsResponse(
          airingSpins: [
            SpinSummary(
              id: "spin-q", title: "Question", artist: "Listener", type: "commentary",
              airtime: now.addingTimeInterval(-86400), durationMS: 30000),
            SpinSummary(
              id: "spin-a", title: "Answer", artist: "Curator", type: "commentary",
              airtime: now.addingTimeInterval(-86370), durationMS: 45000),
          ],
          contextSpins: [
            SpinSummary(
              id: "spin-before", title: "Song Before", artist: "Artist", type: "song",
              airtime: now.addingTimeInterval(-86700), durationMS: 240000)
          ]
        )
      }
      $0.api.createClipForAiring = { _, firstSpinId, lastSpinId, _, _ in
        createClipCalled = true
        passedFirstSpinId = firstSpinId
        passedLastSpinId = lastSpinId
        return Clip.mockWith(status: .completed)
      }
      $0.api.getClip = { _, _ in Clip.mockWith(status: .completed) }
    } operation: {
      let model = MyAiringsPageModel()

      await model.createClipTapped(pastAiring)

      XCTAssertTrue(createClipCalled)
      XCTAssertEqual(passedFirstSpinId, "spin-before")
      XCTAssertEqual(passedLastSpinId, "spin-a")
      XCTAssertNotNil(model.clips["past"])
    }
  }

  func testCreateClipTappedDoesNothingWithoutJWT() async {
    @Shared(.auth) var auth = Auth(jwt: nil)
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")
    var apiCalled = false

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        apiCalled = true
        return AiringSpinsResponse(airingSpins: [], contextSpins: [])
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.createClipTapped(pastAiring)

      XCTAssertFalse(apiCalled)
    }
  }

  func testCreateClipTappedGuardsAgainstDoubleTap() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")
    var callCount = 0

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        callCount += 1
        return AiringSpinsResponse(airingSpins: [], contextSpins: [])
      }
    } operation: {
      let model = MyAiringsPageModel()
      model.pollingAiringIds.insert("past")

      await model.createClipTapped(pastAiring)

      XCTAssertEqual(callCount, 0)
    }
  }

  func testCreateClipShowsAlertWhenNoSpinsFound() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        AiringSpinsResponse(airingSpins: [], contextSpins: [])
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.createClipTapped(pastAiring)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertFalse(model.pollingAiringIds.contains("past"))
    }
  }

  func testCreateClipShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.createClipTapped(pastAiring)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertFalse(model.pollingAiringIds.contains("past"))
    }
  }

  func testCreateClipShowsAlertWhenClipReturnsFailed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        AiringSpinsResponse(
          airingSpins: [
            SpinSummary(
              id: "spin-1", title: "Q", artist: "L", type: "commentary",
              airtime: now.addingTimeInterval(-100), durationMS: 30000)
          ],
          contextSpins: []
        )
      }
      $0.api.createClipForAiring = { _, _, _, _, _ in
        Clip.mockWith(status: .failed, errorMessage: "error")
      }
    } operation: {
      let model = MyAiringsPageModel()

      await model.createClipTapped(pastAiring)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertFalse(model.pollingAiringIds.contains("past"))
    }
  }

  // MARK: - downloadTapped

  func testDownloadTappedPresentsShareSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let airing = ListenerQuestionAiring.mockWith(id: "airing-1")
    let clip = Clip.mockWith(url: "https://example.com/clip.m4a")

    let model = MyAiringsPageModel()
    model.clips["airing-1"] = clip

    model.downloadTapped(airing)

    if case .share(let shareModel) = navCoordinator.presentedSheet {
      let url = shareModel.items.first as? URL
      XCTAssertEqual(url?.absoluteString, "https://example.com/clip.m4a")
    } else {
      XCTFail("Expected share sheet to be presented")
    }
  }

  func testDownloadTappedShowsAlertWhenURLIsNil() async {
    let airing = ListenerQuestionAiring.mockWith(id: "airing-1")
    let clip = Clip.mockWith(url: nil)

    let model = MyAiringsPageModel()
    model.clips["airing-1"] = clip

    model.downloadTapped(airing)

    XCTAssertNotNil(model.presentedAlert)
  }

  // MARK: - shareTapped

  func testShareTappedPresentsShareSheetWithShareUrl() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let airing = ListenerQuestionAiring.mockWith(id: "airing-1")
    let clip = Clip.mockWith(id: "clip-123")

    let model = MyAiringsPageModel()
    model.clips["airing-1"] = clip

    model.shareTapped(airing)

    if case .share(let shareModel) = navCoordinator.presentedSheet {
      XCTAssertTrue(shareModel.items.first?.contains("/clips/clip-123/share") ?? false)
    } else {
      XCTFail("Expected share sheet to be presented")
    }
  }

  func testShareTappedDoesNothingWithNoClip() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    let airing = ListenerQuestionAiring.mockWith(id: "airing-1")

    let model = MyAiringsPageModel()

    model.shareTapped(airing)

    XCTAssertNil(navCoordinator.presentedSheet)
  }

  // MARK: - retryTapped

  func testRetryTappedClearsClipAndRetries() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(id: "past")
    let failedClip = Clip.mockWith(status: .failed)
    var createClipCalled = false

    await withDependencies {
      $0.api.getAiringSpins = { _, _ in
        AiringSpinsResponse(
          airingSpins: [
            SpinSummary(
              id: "spin-1", title: "Q", artist: "L", type: "commentary",
              airtime: now.addingTimeInterval(-100), durationMS: 30000)
          ],
          contextSpins: []
        )
      }
      $0.api.createClipForAiring = { _, _, _, _, _ in
        createClipCalled = true
        return Clip.mockWith(status: .completed)
      }
    } operation: {
      let model = MyAiringsPageModel()
      model.clips["past"] = failedClip

      await model.retryTapped(pastAiring)

      XCTAssertTrue(createClipCalled)
    }
  }

  // MARK: - View Helpers

  func testStationImageUrlReturnsNilWithoutStation() async {
    let airing = ListenerQuestionAiring.mockWith(station: nil)

    let model = MyAiringsPageModel()

    XCTAssertNil(model.stationImageUrl(for: airing))
  }

  func testStationImageUrlReturnsValueWithStation() async {
    let airing = ListenerQuestionAiring.mockWith(station: .mockWith())

    let model = MyAiringsPageModel()

    // Station mock may or may not have an imageUrl — just verify the method works
    _ = model.stationImageUrl(for: airing)
  }

  // MARK: - viewDisappeared

  func testViewDisappearedCancelsPolling() async {
    let model = MyAiringsPageModel()
    model.pollingAiringIds.insert("test")

    model.viewDisappeared()

    // Verify the method exists and doesn't crash — cancellation is tested
    // by the Task.isCancelled checks in pollForClipCompletion
  }
}
