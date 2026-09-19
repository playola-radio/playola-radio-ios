//
//  AskMeAnythingLivePageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AskMeAnythingLivePageTests {

  private let testStationId = "station-abc"

  private func introItem(durationMS: Int) -> AMAOpeningItem {
    AMAOpeningItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
      content: .intro(.mockWith(id: "intro", durationMS: durationMS)))
  }

  private func acceptVoicetrack(
    named name: String,
    model: AskMeAnythingLivePageModel,
    coordinator: MainContainerNavigationCoordinator
  ) throws {
    model.voicetrackActionTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected recorder push")
      return
    }
    try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/\(name)"), 10)
  }

  @Test func startShowSendsTheReadyOpenerInOrder() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedIds = LockIsolated<[String]>([])
    let model = withDependencies {
      $0.api.startLiveShow = { jwt, stationId, ids in
        expectNoDifference(jwt, "test-jwt")
        expectNoDifference(stationId, "station-abc")
        capturedIds.setValue(ids)
        return StartLiveShowResponse(
          liveShowId: "show-1", scheduledStartsAt: .distantFuture,
          scheduledEndsAt: .distantFuture)
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 30_000))
    model.openingItems.append(
      AMAOpeningItem(id: UUID(), content: .song(.mockWith(id: "song", durationMS: 570_000))))

    await model.startShowButtonTapped()

    expectNoDifference(capturedIds.value, ["intro", "song"])
    expectNoDifference(model.broadcast.liveShowId, "show-1")
    #expect(model.isShowActive)
    #expect(model.openingItems.isEmpty)
  }

  @Test func repeatedStartTapsSendOnlyOneRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let started = AsyncStream<Void>.makeStream()
    let finish = AsyncStream<Void>.makeStream()
    let calls = LockIsolated(0)
    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        calls.withValue { $0 += 1 }
        started.continuation.yield(())
        var iterator = finish.stream.makeAsyncIterator()
        await iterator.next()
        return StartLiveShowResponse(
          liveShowId: "show", scheduledStartsAt: .distantFuture, scheduledEndsAt: .distantFuture)
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))
    let firstStart = Task { await model.startShowButtonTapped() }
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()
    await model.startShowButtonTapped()
    finish.continuation.yield(())
    await firstStart.value
    expectNoDifference(calls.value, 1)
    expectNoDifference(model.broadcast.liveShowId, "show")
    #expect(!model.isStartingShow)
  }

  @Test func playbackAdvancingPastTheShowReturnsToSetup() async {
    let currentDate = LockIsolated(Date(timeIntervalSince1970: 1_000_000))
    await withDependencies {
      $0.date = DateGenerator { currentDate.value }
      $0.api.fetchSchedule = { _, _ in
        [
          .mockWith(
            id: "last", airtime: currentDate.value.addingTimeInterval(-30),
            audioBlock: .mockWith(endOfMessageMS: 60_000), liveShowId: "show")
        ]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      await model.viewAppeared()
      #expect(model.isShowActive)
      currentDate.withValue { $0 += 60 }
      model.broadcast.tick()
      model.schedulePlaybackChanged()
      #expect(!model.isShowActive)
      #expect(model.setupLayerInteractive)
    }
  }

  @Test func startShowExplainsAnUnavailableTime() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        throw APIError.liveShowUnavailable(delayUntil: Date(timeIntervalSince1970: 1_000_000))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))

    await model.startShowButtonTapped()

    expectNoDifference(model.presentedAlert?.title, "Show Unavailable")
    #expect(model.presentedAlert?.message?.contains("Try again after") == true)
  }

  @Test func detectsUpcomingShowBeforeItStartsAndKeepsFillerOnlyShowsActive() async {
    for isFiller in [false, true] {
      let now = Date(timeIntervalSince1970: 1_000_000)
      await withDependencies {
        $0.date.now = now
        $0.api.fetchSchedule = { stationId, extended in
          expectNoDifference(stationId, "station-abc")
          #expect(extended)
          return [
            .mockWith(
              id: "ended", airtime: now.addingTimeInterval(-1_000),
              audioBlock: .mockWith(endOfMessageMS: 30_000), liveShowId: "old"),
            .mockWith(
              id: "upcoming", airtime: now.addingTimeInterval(300),
              liveShowId: "show", isFiller: isFiller),
          ]
        }
      } operation: {
        let model = AskMeAnythingLivePageModel(stationId: testStationId)
        await model.viewAppeared()
        expectNoDifference(model.broadcast.liveShowId, "show")
        #expect(model.isShowActive)
        #expect(!model.setupLayerInteractive)
      }
    }
  }

  @Test func detectsPlayingShowBeforeAnotherUpcomingShow() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = now
      $0.api.fetchSchedule = { _, _ in
        [
          .mockWith(
            airtime: now.addingTimeInterval(-30),
            audioBlock: .mockWith(endOfMessageMS: 180_000), liveShowId: "current"),
          .mockWith(airtime: now.addingTimeInterval(600), liveShowId: "future"),
        ]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      await model.viewAppeared()
      expectNoDifference(model.broadcast.liveShowId, "current")
    }
  }

  @Test func scheduleFailureOffersRetryWithoutEnablingStart() async {
    let model = withDependencies {
      $0.api.fetchSchedule = { _, _ in throw APIError.liveShowFinished }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))
    await model.viewAppeared()
    #expect(!model.isStartShowEnabled)
    #expect(model.scheduleRetryVisible)
    expectNoDifference(model.presentedAlert?.title, "Error")
  }

  @Test func startDoesNotSkipAnUploadingVoicetrack() async {
    let calls = LockIsolated(0)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        calls.withValue { $0 += 1 }
        throw APIError.liveShowFinished
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(),
        content: .voicetrack(
          LocalVoicetrack(originalURL: URL(fileURLWithPath: "/tmp/pending.wav"), title: "Pending"),
          completedDurationMS: nil)))
    await model.startShowButtonTapped()
    #expect(!model.isStartShowEnabled)
    expectNoDifference(calls.value, 0)
  }

  @Test func endingRetainsLivePageUntilScheduledEndAndSubmitsOnlyOnce() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let calls = LockIsolated(0)
    await withDependencies {
      $0.date.now = now
      $0.api.endLiveShow = { jwt, stationId, showId, audioBlockId in
        expectNoDifference(
          [jwt, stationId, showId, audioBlockId],
          ["test-jwt", "station-abc", "show", "outro"])
        calls.withValue { $0 += 1 }
        return EndLiveShowResponse(
          endingSpinId: "ending", effectiveEndsAt: now.addingTimeInterval(300))
      }
      $0.api.fetchSchedule = { _, _ in
        [.mockWith(airtime: now.addingTimeInterval(60), liveShowId: "show")]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      model.broadcast.liveShowId = "show"
      await model.outroRecordingCompleted(.mockWith(id: "outro"))
      await model.endShowButtonTapped()
      expectNoDifference(calls.value, 1)
      #expect(model.isShowActive)
      #expect(!model.isEndShowEnabled)
      expectNoDifference(model.endShowButtonTitle, "Show Ending")
    }
  }

  @Test func failedEndingRetriesTheUploadedOutro() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let calls = LockIsolated<[String]>([])
    let model = withDependencies {
      $0.api.endLiveShow = { _, _, _, blockId in
        calls.withValue { $0.append(blockId) }
        throw APIError.liveShowFinished
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.broadcast.liveShowId = "show"
    await model.outroRecordingCompleted(.mockWith(id: "outro"))
    #expect(model.isShowActive)
    #expect(model.isEndShowEnabled)
    expectNoDifference(model.endShowButtonTitle, "Retry End Show")
    await model.endShowButtonTapped()
    expectNoDifference(calls.value, ["outro", "outro"])
    expectNoDifference(model.presentedAlert?.title, "Unable to End Show")
  }

  @Test func endShowPushesOutroRecorderAndBackingOutDoesNotEndShow() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingLivePage(model))
    model.broadcast.liveShowId = "show"
    await model.endShowButtonTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected outro recorder")
      return
    }
    expectNoDifference(recorder.screenTitle, "Record Outro")
    #expect(recorder.onUseRecording != nil)
    #expect(recorder.onCompleted != nil)
    coordinator.pop()
    model.backButtonTapped()
    #expect(coordinator.path.isEmpty)
    expectNoDifference(model.broadcast.liveShowId, "show")
  }

  @Test func displaysIntroCopy() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)

    expectNoDifference(model.navigationTitle, "Ask Me Anything")
    expectNoDifference(model.setupLabel, "SETUP")
    expectNoDifference(model.introTitle, "First, record your intro")
    expectNoDifference(model.recordIntroButtonTitle, "Record Intro")
    expectNoDifference(
      model.preparationReassurance, "Your station will keep playing while you prepare.")
  }

  @Test func startShowIsDisabledAtZeroProgress() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)

    expectNoDifference(model.preparedAudioLabel, "0:00 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Record your intro")
    expectNoDifference(model.readyProgress, 0)
    #expect(!model.isStartShowEnabled)
  }

  @Test func backButtonTappedPopsNavigation() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingLivePage(model))

    model.backButtonTapped()

    #expect(coordinator.path.isEmpty)
  }

  // MARK: - Intro-recorded state (01b · Build Your Opening)

  @Test func startsInIntroPromptState() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)

    #expect(!model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 1)
    #expect(model.introPromptInteractive)
    expectNoDifference(model.openingPlaylistOpacity, 0)
    #expect(!model.openingPlaylistInteractive)
  }

  @Test func hiddenSetupLayerAccessibilityFlipsWithRecordedIntro() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)

    #expect(!model.introPromptAccessibilityHidden)
    #expect(model.openingPlaylistAccessibilityHidden)

    model.openingItems.append(introItem(durationMS: 30_000))

    #expect(model.introPromptAccessibilityHidden)
    #expect(!model.openingPlaylistAccessibilityHidden)
  }

  @Test func recordIntroButtonPushesRecorderThatFlipsToOpeningPlaylist() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingLivePage(model))

    model.recordIntroButtonTapped()

    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected record page to be pushed")
      return
    }
    await withDependencies {
      $0.uuid = .incrementing
    } operation: {
      await recorder.onCompleted?(.mockWith(durationMS: 30000))
    }

    #expect(model.hasRecordedIntro)
    expectNoDifference(model.openingItems.count, 1)
    guard case .intro? = model.openingItems.first?.content else {
      Issue.record("Expected the recorded item to be an intro")
      return
    }
    expectNoDifference(model.introPromptOpacity, 0)
    #expect(!model.introPromptInteractive)
    expectNoDifference(model.openingPlaylistOpacity, 1)
    #expect(model.openingPlaylistInteractive)
  }

  @Test func nonPositiveIntroDurationDoesNotFlipToOpeningPlaylist() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingLivePage(model))

    model.recordIntroButtonTapped()

    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected record page to be pushed")
      return
    }
    await recorder.onCompleted?(.mockWith(durationMS: 0))
    await recorder.onCompleted?(.mockWith(durationMS: -30000))

    #expect(!model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 1)
    expectNoDifference(model.readyProgress, 0)
  }

  @Test func displaysOpeningPlaylistCopyAfterIntroRecorded() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    expectNoDifference(model.openingPlaylistTitle, "Your opening playlist")
    expectNoDifference(
      model.openingPlaylistSubtitle, "Your station keeps playing while you prepare.")
    expectNoDifference(model.addSectionTitle, "Let\u{2019}s get a little ahead")
    expectNoDifference(
      model.addSectionExplanation,
      "Build the first 10 minutes of your show with songs and voicetracks. "
        + "Use Voicetrack to record a quick intro for a song.")
    expectNoDifference(model.voicetrackActionLabel, "Voicetrack")
    expectNoDifference(model.songActionLabel, "Song")
    expectNoDifference(model.qaActionLabel, "Q/A")
  }

  @Test func bottomBarReflectsRecordedIntroProgress() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    expectNoDifference(model.preparedAudioLabel, "0:30 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Add 9:30 more")
    expectNoDifference(model.readyProgress, 0.05)
    #expect(!model.isStartShowEnabled)
  }

  @Test func startShowEnablesAtTenMinutesOfReadyAudio() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)

    model.openingItems.append(introItem(durationMS: 599_999))
    #expect(!model.isStartShowEnabled)
    expectNoDifference(model.readinessHint, "Add 0:01 more")

    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!,
        content: .song(.mockWith(id: "s", durationMS: 1))))
    #expect(model.isStartShowEnabled)
    expectNoDifference(model.readyProgress, 1)
    expectNoDifference(model.readinessHint, "Ready to start")
  }

  @Test func readinessColorsReflectBuildingState() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    #expect(!model.isStartShowEnabled)
    expectNoDifference(model.readinessHintColor, .playolaTextSecondary)
    expectNoDifference(model.readyProgressColor, .playolaRed)
    expectNoDifference(model.startShowButtonBackgroundColor, .playolaSurfaceRaised)
    expectNoDifference(model.startShowButtonBorderColor, .playolaGlassHairline)
    expectNoDifference(model.startShowButtonTitleColor, .playolaGray)
  }

  @Test func readinessColorsTurnGreenWhenReady() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 600_000))

    #expect(model.isStartShowEnabled)
    expectNoDifference(model.readinessHintColor, .playolaSuccessGreen)
    expectNoDifference(model.readyProgressColor, .playolaSuccessGreen)
    expectNoDifference(model.startShowButtonBackgroundColor, .playolaRed)
    expectNoDifference(model.startShowButtonBorderColor, .playolaRed)
    expectNoDifference(model.startShowButtonTitleColor, .white)
  }

  @Test func songActionPresentsCuratorPickerAndAddingAppendsWithoutDismissing() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingLivePage(model))

    model.songActionTapped()

    guard case .curatorSongPicker(let picker) = coordinator.presentedSheet else {
      Issue.record("Expected curator song picker sheet")
      return
    }

    picker.onAddSong?(.mockWith(id: "song-1", durationMS: 180_000))

    expectNoDifference(model.openingItems.count, 1)
    guard case .song? = model.openingItems.first?.content else {
      Issue.record("Expected first item to be a song")
      return
    }
    #expect(coordinator.presentedSheet != nil)

    picker.onDismiss?()
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func addingSongsSeedsPickerWithAlreadyAddedIds() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingLivePage(model))

    model.songActionTapped()
    guard case .curatorSongPicker(let firstPicker) = coordinator.presentedSheet else {
      Issue.record("Expected curator song picker sheet")
      return
    }
    firstPicker.onAddSong?(.mockWith(id: "already", durationMS: 10_000))
    firstPicker.onDismiss?()

    model.songActionTapped()
    guard case .curatorSongPicker(let secondPicker) = coordinator.presentedSheet else {
      Issue.record("Expected curator song picker sheet")
      return
    }

    #expect(secondPicker.addedSongIds == ["already"])
  }

  @Test func voicetrackAcceptAppendsProcessingRowThenCompletesAndCounts() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let deleted = LockIsolated<[URL]>([])
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { url in deleted.withValue { $0.append(url) } }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, onStatus in
        await onStatus(.completed)
        return .mockWith(id: "vt-block", durationMS: 605_000)
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push")
        return
      }
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      try recorder.onRecordingAccepted?(url, 60)

      expectNoDifference(model.openingItems.count, 1)
      guard case .voicetrack? = model.openingItems.first?.content else {
        Issue.record("Expected first item to be a voicetrack")
        return
      }

      await model.waitForPendingUploads()

      #expect(model.isStartShowEnabled)
      expectNoDifference(deleted.value, [url])
      #expect(model.presentedAlert == nil)
    }
  }

  @Test func lateStatusCallbackDoesNotDowngradeCompletedVoicetrack() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let lateStatus = LockIsolated<(@MainActor @Sendable (LocalVoicetrackStatus) -> Void)?>(nil)
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, onStatus in
        lateStatus.withValue { $0 = onStatus }
        await onStatus(.completed)
        return .mockWith(id: "vt-block", durationMS: 605_000)
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push")
        return
      }
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/vt.wav"), 60)
      await model.waitForPendingUploads()

      #expect(model.isStartShowEnabled)

      lateStatus.value?(.uploading(progress: 0.5))

      #expect(model.isStartShowEnabled)
      expectNoDifference(model.openingItems.first?.readyDurationMS, 605_000)
    }
  }

  @Test func voicetrackUploadFailureRemovesRowAndAlertsAndDeletesFile() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let deleted = LockIsolated<[URL]>([])
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { url in deleted.withValue { $0.append(url) } }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        throw NSError(domain: "test", code: 1)
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push")
        return
      }
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      try recorder.onRecordingAccepted?(url, 60)
      await model.waitForPendingUploads()

      #expect(model.openingItems.isEmpty)
      #expect(model.presentedAlert != nil)
      expectNoDifference(deleted.value, [url])
    }
  }

  @Test func acceptWithoutAuthThrowsAndAddsNothing() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingLivePage(model))

    model.voicetrackActionTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected recorder push")
      return
    }

    #expect(throws: RecordPromptError.self) {
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/vt.wav"), 60)
    }
    #expect(model.openingItems.isEmpty)
  }

  @Test func appendedVoicetracksKeepAppendOrderAndOwnReadyDurations() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let releaseFirst = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let releaseSecond = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { vt, _, _, onStatus in
        let isFirst = vt.originalURL.lastPathComponent.contains("first")
        if isFirst {
          await withCheckedContinuation { continuation in
            releaseFirst.setValue(continuation)
            firstStarted.continuation.yield()
          }
        } else {
          await withCheckedContinuation { continuation in
            releaseSecond.setValue(continuation)
            secondStarted.continuation.yield()
          }
        }
        await onStatus(.completed)
        let ms = isFirst ? 100_000 : 200_000
        return .mockWith(id: vt.originalURL.lastPathComponent, durationMS: ms)
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))

      try acceptVoicetrack(named: "first.wav", model: model, coordinator: coordinator)
      var firstIterator = firstStarted.stream.makeAsyncIterator()
      await firstIterator.next()

      try acceptVoicetrack(named: "second.wav", model: model, coordinator: coordinator)
      var secondIterator = secondStarted.stream.makeAsyncIterator()
      await secondIterator.next()

      let waitTask = Task { await model.waitForPendingUploads() }
      releaseSecond.withValue { $0?.resume() }
      await Task.yield()
      releaseFirst.withValue { $0?.resume() }
      await waitTask.value

      expectNoDifference(model.openingItems.count, 2)
      expectNoDifference(model.openingItems.map(\.readyDurationMS), [100_000, 200_000])
    }
  }

  @Test func openingRowsResolveIntroSongAndVoicetrackDisplayData() {
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        content: .intro(.mockWith(id: "intro", durationMS: 30_000))))
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
        content: .song(
          .mockWith(id: "song", title: "Song X", artist: "Artist Y", durationMS: 200_000))))
    let vt = LocalVoicetrack(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
      originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .uploading(progress: 0.5), createdAt: Date(timeIntervalSince1970: 0), title: "VT")
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!,
        content: .voicetrack(vt, completedDurationMS: nil)))

    let rows = model.openingRows
    expectNoDifference(rows.count, 3)
    expectNoDifference(
      Array(rows.ids),
      [
        UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
        UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!,
      ])
    expectNoDifference(rows[0].title, "Show Intro")
    expectNoDifference(rows[0].subtitle, "Your voice")
    expectNoDifference(rows[0].trailingText, "0:30")
    expectNoDifference(rows[0].trailingIconSystemName, "pin")
    expectNoDifference(rows[0].leadingArtworkOpacity, 0)
    expectNoDifference(rows[0].leadingFallbackOpacity, 1)
    expectNoDifference(rows[1].title, "Song X")
    expectNoDifference(rows[1].subtitle, "Artist Y")
    expectNoDifference(rows[1].trailingText, "3:20")
    expectNoDifference(rows[1].trailingIconSystemName, "checkmark")
    expectNoDifference(rows[1].leadingArtworkOpacity, 1)
    expectNoDifference(rows[1].leadingFallbackOpacity, 0)
    expectNoDifference(rows[2].trailingText, "")
    expectNoDifference(rows[2].processingOpacity, 1)
    expectNoDifference(rows[2].completedOpacity, 0)
  }

  @Test func backButtonCancelsInFlightUploads() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let deleted = LockIsolated<[URL]>([])
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { url in deleted.withValue { $0.append(url) } }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push")
        return
      }
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      try recorder.onRecordingAccepted?(url, 60)
      coordinator.pop()

      model.backButtonTapped()
      await model.waitForPendingUploads()

      #expect(model.presentedAlert == nil)
      #expect(coordinator.path.isEmpty)
      expectNoDifference(deleted.value, [url])
    }
  }

  @Test func coordinatorRemovingSetupCancelsInFlightUploads() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingLivePage(model))
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push")
        return
      }
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/vt.wav"), 60)
      coordinator.pop()
      coordinator.pop()

      await model.waitForPendingUploads()

      #expect(model.presentedAlert == nil)
      #expect(coordinator.path.isEmpty)
    }
  }
}

@Suite(.freshSharedState)
@MainActor
struct AMAOpeningItemTests {
  private func block(_ ms: Int) -> AudioBlock { .mockWith(id: "b", durationMS: ms) }

  private func uuid(_ index: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
  }

  @Test func introAndSongAreAlwaysReadyAndCountFullDuration() {
    let intro = AMAOpeningItem(id: uuid(0), content: .intro(block(30_000)))
    let song = AMAOpeningItem(id: uuid(1), content: .song(block(200_000)))
    #expect(intro.isReady)
    expectNoDifference(intro.readyDurationMS, 30_000)
    #expect(song.isReady)
    expectNoDifference(song.readyDurationMS, 200_000)
  }

  @Test func processingVoicetrackIsNotReadyAndCountsZero() {
    let vt = LocalVoicetrack(
      id: uuid(2), originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .uploading(progress: 0.5), createdAt: Date(timeIntervalSince1970: 0),
      title: "VT")
    let item = AMAOpeningItem(id: uuid(3), content: .voicetrack(vt, completedDurationMS: nil))
    #expect(!item.isReady)
    expectNoDifference(item.readyDurationMS, 0)
  }

  @Test func completedVoicetrackWithDurationIsReadyAndCountsThatDuration() {
    var vt = LocalVoicetrack(
      id: uuid(4), originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .completed, createdAt: Date(timeIntervalSince1970: 0), title: "VT")
    vt.audioBlockId = "vt-block"
    let item = AMAOpeningItem(id: uuid(5), content: .voicetrack(vt, completedDurationMS: 45_000))
    #expect(item.isReady)
    expectNoDifference(item.readyDurationMS, 45_000)
  }
}
