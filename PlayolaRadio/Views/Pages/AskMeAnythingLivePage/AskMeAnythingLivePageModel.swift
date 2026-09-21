//
//  AskMeAnythingLivePageModel.swift
//  PlayolaRadio
//

import CasePaths
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class AskMeAnythingLivePageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.uuid) var uuid
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator
  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    self.broadcast = BroadcastPageModel(stationId: stationId, stationName: "Ask Me Anything")
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  private let targetMilliseconds = 600_000

  var displayDate = Date.distantPast
  var scheduledStartsAt: Date?
  var listenerCount: Int?
  var listenerQuestions: [ListenerQuestion] = []
  var lastPromotedFiller: (title: String, date: Date)?
  var hasPresentedSchedule = false
  var isAddingToShow = false
  var isEditingSchedule = false
  var isAwaitingStartedSchedule = false

  var openingItems: IdentifiedArrayOf<AMAOpeningItem> = []
  let broadcast: BroadcastPageModel
  var isCheckingSchedule = false
  var isStartingShow = false
  var isEndingShow = false
  private var hasScheduleLoadFailed = false
  var outroStagingId: String?
  var endingSpinId: String?
  var schedulingItemId: String?
  var failedSchedulingItemId: String?
  var effectiveEndsAt: Date?

  var presentedAlert: PlayolaAlert? {
    get { broadcast.presentedAlert }
    set { broadcast.presentedAlert = newValue }
  }

  @ObservationIgnored var uploadTasks: [UUID: Task<Void, Never>] = [:]

  // MARK: - User Actions

  func viewAppeared() async {
    guard !isAddingToShow, !isEndingShow else { return }
    isCheckingSchedule = true
    defer { isCheckingSchedule = false }
    async let metadata: Void = loadLiveMetadata()
    await broadcast.viewAppeared(trackScreenView: false)
    await metadata
    hasScheduleLoadFailed = broadcast.schedule == nil
    updateShowFromSchedule()
    updateLivePresentation()
    isCheckingSchedule = false
    await schedulePendingAudio()
  }

  func schedulePlaybackChanged() {
    guard !isStartingShow, !isEndingShow else { return }
    updateShowFromSchedule()
    updateLivePresentation()
  }

  func backButtonTapped() {
    setupAbandoned()
    navigationCoordinator.pop()
  }

  func setupAbandoned() {
    cancelUploads()
    broadcast.stagingItems.removeAll()
  }

  func recordIntroButtonTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingIntro(stationId: stationId)
    recorder.onCompleted = { [weak self] audioBlock in
      guard let self, audioBlock.durationMS > 0 else { return }
      guard !openingItems.contains(where: { $0.content.is(\.intro) }) else { return }
      openingItems.insert(
        AMAOpeningItem(id: uuid(), content: .intro(audioBlock)), at: 0)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func voicetrackActionTapped() {
    let showId = broadcast.liveShowId
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: stationId)
    recorder.onRecordingAccepted = { [weak self] url, _ in
      guard let self else { return }
      guard broadcast.liveShowId == showId, showId == nil || canAddLiveAudio else {
        throw CancellationError()
      }
      try acceptVoicetrack(url: url)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func waitForPendingUploads() async {
    while let task = uploadTasks.values.first {
      await task.value
    }
  }

  func songActionTapped() {
    let showId = broadcast.liveShowId
    let picker = CuratorSongPickerPageModel(
      stationId: stationId, initialAddedSongIds: addedSongIds)
    picker.onAddSong = { [weak self] audioBlock in
      guard let self, broadcast.liveShowId == showId else { return }
      addSong(audioBlock)
    }
    picker.onDismiss = { [weak self] in
      self?.$navigationCoordinator.withLock { $0.presentedSheet = nil }
    }
    navigationCoordinator.presentedSheet = .curatorSongPicker(picker)
  }

  func qaActionTapped() {
    navigationCoordinator.push(
      .broadcastersListenerQuestionPage(BroadcastersListenerQuestionPageModel(stationId: stationId))
    )
  }

  func startShowButtonTapped() async {
    guard isStartShowEnabled else { return }
    guard let jwt = auth.jwt else {
      presentedAlert = showAlert(title: "Sign In Required", message: "Sign in to start your show.")
      return
    }
    isStartingShow = true
    defer { isStartingShow = false }
    do {
      let response = try await api.startLiveShow(
        jwt, stationId, openingItems.compactMap(\.audioBlockId))
      broadcast.liveShowId = response.liveShowId
      scheduledStartsAt = response.scheduledStartsAt
      broadcast.visibleFillerIds = []
      hasPresentedSchedule = false
      effectiveEndsAt = nil
      outroStagingId = nil
      endingSpinId = nil
      failedSchedulingItemId = nil
      isAwaitingStartedSchedule = true
      displayDate = now
      await broadcast.loadSchedule()
      updateLivePresentation()
    } catch APIError.liveShowUnavailable(let delayUntil) {
      let message =
        delayUntil.map {
          "Another show or scheduled program is still on air. Try again after "
            + $0.formatted(date: .abbreviated, time: .shortened) + "."
        } ?? "Another show or scheduled program is still on air. Please try again later."
      presentedAlert = showAlert(title: "Show Unavailable", message: message)
    } catch {
      presentedAlert = showAlert(title: "Unable to Start Show", message: error.localizedDescription)
    }
  }

  func endShowButtonTapped() async {
    guard isEndShowEnabled, let showId = broadcast.liveShowId else { return }
    if outroStagingId != nil {
      await retryAddingAudio()
      return
    }
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId: stationId)
    recorder.onUseRecording = nil
    recorder.onRecordingAccepted = { [weak self] url, _ in
      guard let self else { return }
      guard broadcast.liveShowId == showId, isEndShowEnabled else { throw CancellationError() }
      try acceptVoicetrack(url: url, isOutro: true)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var setupLabel: String { isShowActive ? "LIVE" : "SETUP" }
  var isShowActive: Bool { broadcast.liveShowId != nil }
  var setupLayerOpacity: Double { isShowActive ? 0 : 1 }
  var setupLayerInteractive: Bool { !isShowActive && !isCheckingSchedule && !isStartingShow }
  var setupLayerAccessibilityHidden: Bool { isShowActive }
  var activeLayerOpacity: Double { isShowActive ? 1 : 0 }
  var activeLayerInteractive: Bool { isShowActive }
  var activeLayerAccessibilityHidden: Bool { !isShowActive }
  var scheduleRetryVisible: Bool {
    hasScheduleLoadFailed || (isAwaitingStartedSchedule && !isScheduleProcessing)
  }
  var scheduleRetryOpacity: Double { scheduleRetryVisible ? 1 : 0 }
  var scheduleRetryAccessibilityHidden: Bool { !scheduleRetryVisible }
  var scheduleRetryTitle: String { "Retry Loading Show" }
  var loadingOpacity: Double { isCheckingSchedule && !isShowActive ? 1 : 0 }
  var loadingAccessibilityHidden: Bool { loadingOpacity == 0 }
  var isEndShowEnabled: Bool {
    isShowActive && !isScheduleProcessing && !isAwaitingStartedSchedule && effectiveEndsAt == nil
      && (outroStagingId == nil || failedSchedulingItemId == outroStagingId)
  }
  var endShowButtonTitle: String {
    if effectiveEndsAt != nil { return "Show Ending" }
    if let outroStagingId {
      return failedSchedulingItemId == outroStagingId ? "Retry End Show" : "Ending Show…"
    }
    return "End Show"
  }

  var hasRecordedIntro: Bool { openingItems.contains { $0.content.is(\.intro) } }
  var introPromptOpacity: Double { hasRecordedIntro ? 0 : 1 }
  var introPromptInteractive: Bool { !hasRecordedIntro }
  var introPromptAccessibilityHidden: Bool { hasRecordedIntro }
  var openingPlaylistOpacity: Double { hasRecordedIntro ? 1 : 0 }
  var openingPlaylistInteractive: Bool { hasRecordedIntro }
  var openingPlaylistAccessibilityHidden: Bool { !hasRecordedIntro }

  var introTitle: String { "First, record your intro" }
  var introBody: String {
    "Tell your listeners you\u{2019}re about to do an Ask Me Anything session."
      + "\n\nAsk them to tap the Question button on the Player screen to send a question. "
      + "Let them know you\u{2019}ll do your best to answer as many as you can."
  }
  var recordIntroButtonTitle: String { "Record Intro" }
  var preparationReassurance: String { "Your station will keep playing while you prepare." }

  var openingPlaylistTitle: String { "Your opening playlist" }
  var openingPlaylistSubtitle: String { "Your station keeps playing while you prepare." }

  var openingRows: IdentifiedArrayOf<AMAOpeningRowData> {
    IdentifiedArray(
      uniqueElements: openingItems.map { item in
        switch item.content {
        case .intro(let block):
          return AMAOpeningRowData(
            id: item.id, title: "Show Intro", subtitle: "Your voice",
            subtitleColor: .playolaTextDisabled, iconSystemName: "mic", albumImageUrl: nil,
            leadingArtworkOpacity: 0, leadingFallbackOpacity: 1,
            trailingText: durationLabel(block.durationMS), trailingIconSystemName: "pin",
            processingOpacity: 0, completedOpacity: 1)
        case .song(let block):
          return AMAOpeningRowData(
            id: item.id, title: block.title, subtitle: block.artist,
            subtitleColor: .playolaTextDisabled, iconSystemName: "music.note",
            albumImageUrl: block.imageUrl, leadingArtworkOpacity: 1, leadingFallbackOpacity: 0,
            trailingText: durationLabel(block.durationMS), trailingIconSystemName: "checkmark",
            processingOpacity: 0, completedOpacity: 1)
        case .voicetrack(let voicetrack, let completedDurationMS):
          let isProcessing = voicetrack.isProcessing
          return AMAOpeningRowData(
            id: item.id, title: voicetrack.title, subtitle: voicetrack.subtitleText,
            subtitleColor: voicetrack.subtitleColor, iconSystemName: "mic", albumImageUrl: nil,
            leadingArtworkOpacity: 0, leadingFallbackOpacity: 1,
            trailingText: completedDurationMS.map { durationLabel($0) } ?? "",
            trailingIconSystemName: "checkmark", processingOpacity: isProcessing ? 1 : 0,
            completedOpacity: isProcessing ? 0 : 1)
        }
      })
  }

  var addSectionTitle: String { "Let\u{2019}s get a little ahead" }
  var addSectionExplanation: String {
    "Build the first 10 minutes of your show with songs and voicetracks. "
      + "Use Voicetrack to record a quick intro for a song."
  }
  var voicetrackActionLabel: String { "Voicetrack" }
  var songActionLabel: String { "Song" }
  var qaActionLabel: String { "Q/A" }

  private var readyMilliseconds: Int {
    openingItems.reduce(0) { $0 + $1.readyDurationMS }
  }

  var preparedAudioLabel: String {
    "\(durationLabel(readyMilliseconds)) / \(durationLabel(targetMilliseconds)) ready"
  }
  var readinessHint: String {
    guard hasRecordedIntro else { return "Record your intro" }
    if !openingItems.allSatisfy(\.isReady) { return "Waiting for recordings to upload" }
    if isStartShowEnabled { return "Ready to start" }
    return "Add \(durationLabelCeil(max(0, targetMilliseconds - readyMilliseconds))) more"
  }
  var readyProgress: Double {
    min(1, Double(readyMilliseconds) / Double(targetMilliseconds))
  }
  var readinessHintColor: Color {
    isStartShowEnabled ? .playolaSuccessGreen : .playolaTextSecondary
  }
  var readyProgressColor: Color {
    isStartShowEnabled ? .playolaSuccessGreen : .playolaRed
  }

  var startShowButtonTitle: String { isStartingShow ? "Starting Show…" : "Start Show" }
  var isStartShowEnabled: Bool {
    readyMilliseconds >= targetMilliseconds
      && openingItems.allSatisfy(\.isReady) && !isStartingShow && !isCheckingSchedule
      && !hasScheduleLoadFailed && !isShowActive
  }
  var startShowButtonTitleColor: Color { isStartShowEnabled ? .white : .playolaGray }
  var startShowButtonBackgroundColor: Color {
    isStartShowEnabled ? .playolaRed : .playolaSurfaceRaised
  }
  var startShowButtonBorderColor: Color {
    isStartShowEnabled ? .playolaRed : .playolaGlassHairline
  }

  // MARK: - Private Helpers

  private func updateShowFromSchedule() {
    guard !isAwaitingStartedSchedule else { return }
    guard let schedule = broadcast.schedule else { return }
    let showId =
      schedule.nowPlaying()?.liveShowId
      ?? schedule.current().first(where: { $0.liveShowId != nil })?.liveShowId
    if broadcast.liveShowId != showId {
      effectiveEndsAt = nil
      outroStagingId = nil
      endingSpinId = nil
      failedSchedulingItemId = nil
      broadcast.liveShowId = showId
      scheduledStartsAt = nil
      broadcast.visibleFillerIds = []
      lastPromotedFiller = nil
      hasPresentedSchedule = false
      cancelUploads()
      broadcast.stagingItems = []
    }
  }

  private func showAlert(title: String, message: String) -> PlayolaAlert {
    PlayolaAlert(title: title, message: message, dismissButton: .cancel(Text("OK")))
  }

  private var addedSongIds: Set<String> {
    Set(
      openingItems.compactMap { item -> String? in
        guard case .song(let block) = item.content else { return nil }
        return block.id
      })
  }

  private func addSong(_ audioBlock: AudioBlock) {
    if let showId = broadcast.liveShowId {
      guard canAddLiveAudio else { return }
      enqueueSong(audioBlock)
      Task { await schedulePendingAudio(for: showId) }
      return
    }
    openingItems.append(AMAOpeningItem(id: uuid(), content: .song(audioBlock)))
  }

  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func durationLabelCeil(_ milliseconds: Int) -> String {
    let total = Int((Double(max(0, milliseconds)) / 1000).rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}
