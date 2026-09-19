//
//  AskMeAnythingSetupPageTests.swift
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
struct AskMeAnythingSetupPageTests {

  private let testStationId = "station-abc"

  private func introItem(durationMS: Int) -> AMAOpeningItem {
    AMAOpeningItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
      content: .intro(.mockWith(id: "intro", durationMS: durationMS)))
  }

  private func acceptVoicetrack(
    named name: String,
    model: AskMeAnythingSetupPageModel,
    coordinator: MainContainerNavigationCoordinator
  ) throws {
    model.voicetrackActionTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected recorder push")
      return
    }
    try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/\(name)"), 10)
  }

  @Test func displaysIntroCopy() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    expectNoDifference(model.navigationTitle, "Ask Me Anything")
    expectNoDifference(model.setupLabel, "SETUP")
    expectNoDifference(model.introTitle, "First, record your intro")
    expectNoDifference(model.recordIntroButtonTitle, "Record Intro")
    expectNoDifference(
      model.preparationReassurance, "Your station will keep playing while you prepare.")
  }

  @Test func startShowIsDisabledAtZeroProgress() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    expectNoDifference(model.preparedAudioLabel, "0:00 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Record your intro")
    expectNoDifference(model.readyProgress, 0)
    #expect(!model.isStartShowEnabled)
  }

  @Test func backButtonTappedPopsNavigation() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

    model.backButtonTapped()

    #expect(coordinator.path.isEmpty)
  }

  // MARK: - Intro-recorded state (01b · Build Your Opening)

  @Test func startsInIntroPromptState() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    #expect(!model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 1)
    #expect(model.introPromptInteractive)
    expectNoDifference(model.openingPlaylistOpacity, 0)
    #expect(!model.openingPlaylistInteractive)
  }

  @Test func hiddenSetupLayerAccessibilityFlipsWithRecordedIntro() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    #expect(!model.introPromptAccessibilityHidden)
    #expect(model.openingPlaylistAccessibilityHidden)

    model.openingItems.append(introItem(durationMS: 30_000))

    #expect(model.introPromptAccessibilityHidden)
    #expect(!model.openingPlaylistAccessibilityHidden)
  }

  @Test func recordIntroButtonPushesRecorderThatFlipsToOpeningPlaylist() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

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
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

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
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
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
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    expectNoDifference(model.preparedAudioLabel, "0:30 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Add 9:30 more")
    expectNoDifference(model.readyProgress, 0.05)
    #expect(!model.isStartShowEnabled)
  }

  @Test func startShowEnablesAtTenMinutesOfReadyAudio() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

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
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    #expect(!model.isStartShowEnabled)
    expectNoDifference(model.readinessHintColor, .playolaTextSecondary)
    expectNoDifference(model.readyProgressColor, .playolaRed)
    expectNoDifference(model.startShowButtonBackgroundColor, .playolaSurfaceRaised)
    expectNoDifference(model.startShowButtonBorderColor, .playolaGlassHairline)
    expectNoDifference(model.startShowButtonTitleColor, .playolaGray)
  }

  @Test func readinessColorsTurnGreenWhenReady() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
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
      AskMeAnythingSetupPageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingSetupPage(model))

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
      AskMeAnythingSetupPageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingSetupPage(model))

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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

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
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

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

  @Test func readyAudioBlockIdsAreOrderedAndSkipUnreadyVoicetracks() {
    @Shared(.auth) var auth = Auth(jwt: "test-token")

    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    let introBlock = AudioBlock.mockWith(id: "intro-1")
    let songBlock = AudioBlock.mockWith(id: "song-1")
    model.openingItems = [
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
        content: .intro(introBlock)),
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!,
        content: .song(songBlock)),
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!,
        content: .voicetrack(
          LocalVoicetrack(originalURL: URL(string: "file:///v.wav")!, title: "V"),
          completedDurationMS: nil)),
    ]

    expectNoDifference(model.readyAudioBlockIds, ["intro-1", "song-1"])
    #expect(model.allOpeningItemsReady == false)
  }

  @Test func openingRowsResolveIntroSongAndVoicetrackDisplayData() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))
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

  @Test func startShowNavigatesToLiveOnSuccess() async {
    @Shared(.auth) var auth = Auth(jwt: "t")
    @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow?
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    @Shared(.activeTab) var activeTab = .artistDashboard

    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        StartLiveShowResponse(
          liveShowId: "show-1", scheduledStartsAt: Date(), scheduledEndsAt: Date())
      }
    } operation: {
      AskMeAnythingSetupPageModel(stationId: "station-1")
    }
    model.openingItems = [
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!,
        content: .intro(.mockWith(id: "i", durationMS: 600_000)))
    ]
    coordinator.artistDashboardPath = [.askMeAnythingSetupPage(model)]

    await model.startShowButtonTapped()

    #expect(activeLiveShow?.liveShowId == "show-1")
    guard case .askMeAnythingLivePage = coordinator.artistDashboardPath[0] else {
      Issue.record("expected live page after start")
      return
    }
  }

  @Test func duplicateStartTapsRejected() async {
    @Shared(.auth) var auth = Auth(jwt: "t")
    @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow?
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    @Shared(.activeTab) var activeTab = .artistDashboard

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        callCount.withValue { $0 += 1 }
        return StartLiveShowResponse(
          liveShowId: "show-1", scheduledStartsAt: Date(), scheduledEndsAt: Date())
      }
    } operation: {
      AskMeAnythingSetupPageModel(stationId: "station-1")
    }
    model.openingItems = [
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!,
        content: .intro(.mockWith(id: "i", durationMS: 600_000)))
    ]
    coordinator.artistDashboardPath = [.askMeAnythingSetupPage(model)]

    await model.startShowButtonTapped()
    await model.startShowButtonTapped()  // no longer .editing → rejected

    #expect(callCount.value == 1)
  }

  @Test func startShowUnavailableShowsAlertAndReturnsToEditing() async {
    @Shared(.auth) var auth = Auth(jwt: "t")
    @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow?
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = withDependencies {
      $0.api.startLiveShow = { _, _, _ in
        throw APIError.liveShowUnavailable(delayUntil: Date(timeIntervalSince1970: 2_000_000))
      }
    } operation: {
      AskMeAnythingSetupPageModel(stationId: "station-1")
    }
    model.openingItems = [
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D3")!,
        content: .intro(.mockWith(id: "i", durationMS: 600_000)))
    ]

    await model.startShowButtonTapped()

    #expect(model.submissionState == .editing)
    #expect(model.presentedAlert != nil)
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
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))
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
