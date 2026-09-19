//
//  AskMeAnythingSetupPageModel.swift
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
class AskMeAnythingSetupPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.uuid) var uuid
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeLiveShow) var activeLiveShow

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  private let targetMilliseconds = 600_000

  var openingItems: IdentifiedArrayOf<AMAOpeningItem> = []
  var presentedAlert: PlayolaAlert?

  enum SubmissionState: Equatable {
    case editing, preparing, submitting, scheduled, outcomeUnknown
  }
  private(set) var submissionState: SubmissionState = .editing

  @ObservationIgnored private var uploadTasks: [UUID: Task<Void, Never>] = [:]

  // MARK: - User Actions

  func backButtonTapped() {
    setupAbandoned()
    navigationCoordinator.pop()
  }

  func setupAbandoned() {
    switch submissionState {
    case .editing, .preparing:
      cancelUploads()
    case .submitting, .scheduled, .outcomeUnknown:
      break  // A committed/in-flight show must not be torn down (spec §8).
    }
  }

  func recordIntroButtonTapped() {
    guard isOpeningEditingEnabled else { return }
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingIntro(stationId: stationId)
    recorder.onCompleted = { [weak self] audioBlock in
      guard let self, isOpeningEditingEnabled, audioBlock.durationMS > 0 else { return }
      guard !openingItems.contains(where: { $0.content.is(\.intro) }) else { return }
      openingItems.insert(
        AMAOpeningItem(id: uuid(), content: .intro(audioBlock)), at: 0)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func voicetrackActionTapped() {
    guard isOpeningEditingEnabled else { return }
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: stationId)
    recorder.onRecordingAccepted = { [weak self] url, _ in
      guard let self else { return }
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
    guard isOpeningEditingEnabled else { return }
    let picker = CuratorSongPickerPageModel(
      stationId: stationId, initialAddedSongIds: addedSongIds)
    picker.onAddSong = { [weak self] audioBlock in
      self?.addSong(audioBlock)
    }
    picker.onDismiss = { [weak self] in
      self?.$navigationCoordinator.withLock { $0.presentedSheet = nil }
    }
    navigationCoordinator.presentedSheet = .curatorSongPicker(picker)
  }

  func qaActionTapped() {}

  func startShowButtonTapped() async {
    // If a prior attempt left the outcome ambiguous (transport failure + the recovery prompt was
    // dismissed), tapping Start again re-checks whether the show actually started rather than
    // silently no-op'ing (spec §8 / Codex ambiguous-start case).
    if submissionState == .outcomeUnknown {
      await recoverStartedShow()
      return
    }
    guard submissionState == .editing else { return }
    guard isStartShowEnabled, hasRecordedIntro else { return }

    submissionState = .preparing
    let intendedItemIds = Set(openingItems.ids)
    await waitForPendingUploads()

    // A failed upload silently removes its row; do not schedule an opening that omits something the
    // curator meant to include (spec §8 step 3). Every intended item must survive and be ready.
    let allIntendedSurvived = intendedItemIds.allSatisfy { openingItems[id: $0] != nil }
    guard hasRecordedIntro, isStartShowEnabled, allOpeningItemsReady, allIntendedSurvived else {
      submissionState = .editing
      presentedAlert = .amaOpeningIncomplete
      return
    }

    guard let jwt = auth.jwt else {
      submissionState = .editing
      presentedAlert = .amaStartFailed("You need to be signed in to go live.")
      return
    }

    let audioBlockIds = readyAudioBlockIds
    submissionState = .submitting
    do {
      let response = try await api.startLiveShow(jwt, stationId, audioBlockIds)
      $activeLiveShow.withLock {
        $0 = ActiveLiveShow(liveShowId: response.liveShowId, stationId: stationId)
      }
      submissionState = .scheduled
      navigateToLive(liveShowId: response.liveShowId, scheduledStartsAt: response.scheduledStartsAt)
    } catch APIError.liveShowUnavailable(let delayUntil) {
      if let delayUntil {
        submissionState = .editing
        presentedAlert = .amaStartUnavailable(delayUntil: delayUntil)
      } else {
        await recoverStartedShow()
      }
    } catch {
      submissionState = .outcomeUnknown
      presentedAlert = .amaStartUnknown { [weak self] in await self?.recoverStartedShow() }
    }
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var setupLabel: String { "SETUP" }

  // Opening edits are frozen once submission begins (spec §8 step 1): the captured opening must
  // match what goes live.
  var isOpeningEditingEnabled: Bool { submissionState == .editing }

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

  var readyAudioBlockIds: [String] {
    openingItems.compactMap { $0.isReady ? $0.audioBlockId : nil }
  }

  var allOpeningItemsReady: Bool {
    openingItems.allSatisfy { $0.isReady }
  }

  var preparedAudioLabel: String {
    "\(durationLabel(readyMilliseconds)) / \(durationLabel(targetMilliseconds)) ready"
  }
  var readinessHint: String {
    guard hasRecordedIntro else { return "Record your intro" }
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

  var startShowButtonTitle: String { "Start Show" }
  var isStartShowEnabled: Bool { readyMilliseconds >= targetMilliseconds }
  var startShowButtonTitleColor: Color { isStartShowEnabled ? .white : .playolaGray }
  var startShowButtonBackgroundColor: Color {
    isStartShowEnabled ? .playolaRed : .playolaSurfaceRaised
  }
  var startShowButtonBorderColor: Color {
    isStartShowEnabled ? .playolaRed : .playolaGlassHairline
  }

  // MARK: - Private Helpers

  private var addedSongIds: Set<String> {
    Set(
      openingItems.compactMap { item -> String? in
        guard case .song(let block) = item.content else { return nil }
        return block.id
      })
  }

  private func addSong(_ audioBlock: AudioBlock) {
    guard isOpeningEditingEnabled else { return }
    openingItems.append(AMAOpeningItem(id: uuid(), content: .song(audioBlock)))
  }

  private func acceptVoicetrack(url: URL) throws {
    guard isOpeningEditingEnabled else { return }
    guard let jwt = auth.jwt else { throw RecordPromptError.notAuthenticated }
    let voicetrack = LocalVoicetrack(
      id: uuid(), originalURL: url, createdAt: now, title: voicetrackTitle(for: now))
    let itemId = uuid()
    openingItems.append(
      AMAOpeningItem(id: itemId, content: .voicetrack(voicetrack, completedDurationMS: nil)))
    let stationId = stationId
    uploadTasks[itemId] = Task { [weak self] in
      await self?.runVoicetrackUpload(
        itemId: itemId, voicetrack: voicetrack, stationId: stationId, jwt: jwt)
    }
  }

  private func runVoicetrackUpload(
    itemId: UUID, voicetrack: LocalVoicetrack, stationId: String, jwt: String
  ) async {
    defer { uploadTasks[itemId] = nil }
    do {
      let audioBlock = try await voicetrackUploadService.processVoicetrack(
        voicetrack, stationId, jwt
      ) { [weak self] status in
        self?.updateVoicetrackStatus(itemId: itemId, status: status)
      }
      guard openingItems[id: itemId] != nil else {
        await audioRecorder.deleteRecording(voicetrack.originalURL)
        return
      }
      completeVoicetrack(itemId: itemId, audioBlock: audioBlock)
      await audioRecorder.deleteRecording(voicetrack.originalURL)
    } catch {
      await audioRecorder.deleteRecording(voicetrack.originalURL)
      guard !Task.isCancelled else { return }
      openingItems.remove(id: itemId)
      presentedAlert = .voicetrackUploadFailed(error.localizedDescription)
    }
  }

  private func updateVoicetrackStatus(itemId: UUID, status: LocalVoicetrackStatus) {
    openingItems[id: itemId]?.content.modify(\.voicetrack) {
      guard $0.1 == nil else { return }
      $0.0.status = status
    }
  }

  private func completeVoicetrack(itemId: UUID, audioBlock: AudioBlock) {
    openingItems[id: itemId]?.content.modify(\.voicetrack) {
      $0.0.status = .completed
      $0.0.audioBlockId = audioBlock.id
      $0.1 = audioBlock.durationMS
    }
  }

  private func voicetrackTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    return "Voicetrack \(formatter.string(from: date).lowercased())"
  }

  private func cancelUploads() {
    for task in uploadTasks.values { task.cancel() }
  }

  private func navigateToLive(liveShowId: String, scheduledStartsAt: Date) {
    let liveModel = AskMeAnythingLivePageModel(
      stationId: stationId, liveShowId: liveShowId, scheduledStartsAt: scheduledStartsAt)
    navigationCoordinator.replaceAskMeAnythingSetup(
      self, with: .askMeAnythingLivePage(liveModel))
  }

  private func recoverStartedShow() async {
    guard auth.jwt != nil else {
      submissionState = .editing
      presentedAlert = .amaStartFailed("You need to be signed in to go live.")
      return
    }
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      // The extended schedule carries ~12h of history; recover the *active* show (an unfinished
      // live spin), earliest first — never an already-finished show from the history window.
      let activeShowSpin =
        spins
        .filter { $0.liveShowId != nil && $0.endtime > now }
        .min(by: { $0.airtime < $1.airtime })
      guard let recovered = activeShowSpin, let recoveredId = recovered.liveShowId else {
        submissionState = .editing
        presentedAlert = .amaStartFailed("We couldn\u{2019}t confirm your show. Please try again.")
        return
      }
      let startsAt = recovered.airtime
      $activeLiveShow.withLock {
        $0 = ActiveLiveShow(liveShowId: recoveredId, stationId: stationId)
      }
      submissionState = .scheduled
      navigateToLive(liveShowId: recoveredId, scheduledStartsAt: startsAt)
    } catch {
      submissionState = .editing
      presentedAlert = .amaStartFailed("We couldn\u{2019}t confirm your show. Please try again.")
    }
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
