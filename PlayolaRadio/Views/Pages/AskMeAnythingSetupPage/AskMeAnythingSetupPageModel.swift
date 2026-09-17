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

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator
  @ObservationIgnored @Shared(.auth) var auth

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

  @ObservationIgnored private var uploadTasks: [UUID: Task<Void, Never>] = [:]

  // MARK: - User Actions

  func backButtonTapped() {
    cancelUploads()
    navigationCoordinator.pop()
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
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: stationId)
    recorder.onRecordingAccepted = { [weak self] url, _ in
      guard let self else { return }
      try acceptVoicetrack(url: url)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func waitForPendingUploads() async {
    for task in Array(uploadTasks.values) {
      await task.value
    }
  }

  func songActionTapped() {
    let search = SongSearchPageModel(searchMode: .all, stationId: stationId)
    search.onDismiss = { [weak self] in
      self?.navigationCoordinator.presentedSheet = nil
    }
    search.onSongSelected = { [weak self] audioBlock in
      guard let self else { return }
      addSong(audioBlock)
      navigationCoordinator.presentedSheet = nil
    }
    navigationCoordinator.presentedSheet = .songSearchPage(search)
  }

  func qaActionTapped() {}

  func startShowButtonTapped() {}

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var setupLabel: String { "SETUP" }

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

  var openingRows: [AMAOpeningRowData] {
    openingItems.map { item in
      switch item.content {
      case .intro(let block):
        return AMAOpeningRowData(
          id: item.id, title: "Show Intro", subtitle: "Your voice",
          subtitleColor: .playolaTextDisabled, iconSystemName: "mic", albumImageUrl: nil,
          trailingText: durationLabel(block.durationMS), isProcessing: false, showsPin: true)
      case .song(let block):
        return AMAOpeningRowData(
          id: item.id, title: block.title, subtitle: block.artist,
          subtitleColor: .playolaTextDisabled, iconSystemName: nil, albumImageUrl: block.imageUrl,
          trailingText: durationLabel(block.durationMS), isProcessing: false, showsPin: false)
      case .voicetrack(let voicetrack, let completedDurationMS):
        return AMAOpeningRowData(
          id: item.id, title: voicetrack.title, subtitle: voicetrack.subtitleText,
          subtitleColor: voicetrack.subtitleColor, iconSystemName: "mic", albumImageUrl: nil,
          trailingText: completedDurationMS.map { durationLabel($0) },
          isProcessing: voicetrack.isProcessing, showsPin: false)
      }
    }
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
    if isStartShowEnabled { return "Ready to start" }
    return "Add \(durationLabelCeil(max(0, targetMilliseconds - readyMilliseconds))) more"
  }
  var readyProgress: Double {
    min(1, Double(readyMilliseconds) / Double(targetMilliseconds))
  }

  var startShowButtonTitle: String { "Start Show" }
  var isStartShowEnabled: Bool { readyMilliseconds >= targetMilliseconds }
  var startShowButtonTitleColor: Color { isStartShowEnabled ? .white : .playolaGray }

  // MARK: - Private Helpers

  private func addSong(_ audioBlock: AudioBlock) {
    openingItems.append(AMAOpeningItem(id: uuid(), content: .song(audioBlock)))
  }

  private func acceptVoicetrack(url: URL) throws {
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

  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func durationLabelCeil(_ milliseconds: Int) -> String {
    let total = Int((Double(max(0, milliseconds)) / 1000).rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}
