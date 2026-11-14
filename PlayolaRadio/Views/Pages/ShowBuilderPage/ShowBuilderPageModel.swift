//
//  ShowBuilderPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

struct ShowBuilderSegmentRow: Identifiable {
  let id: String
  let data: AMAOpeningRowData
}

struct ShowBuilderBanner: Identifiable, Equatable {
  var id: String { title }
  let title: String
  let message: String
}

struct ShowBuilderCalendarBadge: Identifiable {
  var id: Date { date }
  let date: Date
  let timeZone: TimeZone
}

struct ShowBuilderNotSignedIn: LocalizedError {
  var errorDescription: String? { "Please sign in to change your show." }
}

@MainActor
@Observable
class ShowBuilderPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.toast) var toast

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String, episodeId: String?, seriesId: String?, slot: Date?) {
    self.stationId = stationId
    self.episodeId = episodeId
    self.seriesId = seriesId
    self.slot = slot
    super.init()
  }

  // MARK: - Properties

  static let newShowTitle = "New Show"

  let stationId: String
  let seriesId: String?
  let slot: Date?
  private(set) var episodeId: String?
  var episode: CuratorEpisode?
  var settings: StationSchedulingSettings?
  var refusedAsLocked = false
  var isLoading = false
  var presentedAlert: PlayolaAlert?
  var renameText = ""
  private var pendingSaveCount = 0
  @ObservationIgnored private var lastOperation: Task<(any Error)?, Never>?

  var navigationTitle: String { episode?.title ?? Self.newShowTitle }
  var renameButtonTitle: String { "Rename" }
  var renameAlertTitle: String { "Rename Show" }
  var renameFieldPlaceholder: String { "Show name" }
  var renameSaveButtonTitle: String { "Save" }
  var renameCancelButtonTitle: String { "Cancel" }
  var changeTimeButtonTitle: String { "Change" }
  var yourShowTitle: String { "YOUR SHOW" }
  var addSectionTitle: String { "Add to Show" }
  var addSectionExplanation: String { "Added to the end of your playlist" }
  var voicetrackActionLabel: String { "Voicetrack" }
  var songActionLabel: String { "Song" }
  var qaActionLabel: String { "Q/A" }
  var removeRowLabel: String { "Remove" }
  var settingsLoadErrorMessage: String { "The show settings couldn’t load." }
  var loadingOpacity: Double { isLoading ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let jwt = auth.jwt else { return }
    async let settingsLoad: Void = loadSettings(jwt: jwt)
    if episodeId != nil, episode == nil {
      isLoading = true
      defer { isLoading = false }
      _ = await enqueue { [self] in
        await loadEpisode(showsToastOnFailure: true)
        return nil
      }.value
    }
    await settingsLoad
  }

  func save(_ change: @escaping @MainActor (_ episodeId: String) async throws -> Void) async {
    _ = await enqueueSave { _, episodeId in try await change(episodeId) }.value
  }

  func waitForPendingSaves() async {
    _ = await lastOperation?.value
  }

  func renameButtonTapped() {
    guard canRename else { return }
    renameText = navigationTitle
    @Bindable var model = self
    presentedAlert = PlayolaAlert(
      title: renameAlertTitle,
      textFieldPlaceholder: renameFieldPlaceholder,
      text: $model.renameText,
      primaryButtonText: renameSaveButtonTitle,
      primaryAction: { [weak self] in await self?.renameSaveButtonTapped() },
      secondaryButtonText: renameCancelButtonTitle)
  }

  func renameSaveButtonTapped() async {
    let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard canRename, !title.isEmpty, title != navigationTitle else { return }
    _ = await enqueueSave { [weak self, api] jwt, episodeId in
      let updated = try await api.updateEpisode(
        jwt, episodeId, CuratorEpisodeUpdate(title: title))
      self?.episode = self?.episode?.mergingMetadata(from: updated) ?? updated
    }.value
  }

  func voicetrackActionTapped() {
    guard canEditContent else { return }
    let recorder = RecordWithMultiStepPromptModel.recordedShowVoicetrack(stationId: stationId)
    recorder.onCompleted = { [weak self] audioBlock in
      await self?.appendVoicetrackToShow(audioBlock.id)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func songActionTapped() {
    guard canEditContent else { return }
    let picker = CuratorSongPickerPageModel(
      stationId: stationId, initialAddedSongIds: addedSongIds, offersSongRequests: false)
    picker.onAddSong = { [weak self] audioBlock in
      self?.appendToShow([audioBlock.id])
    }
    picker.onDismiss = { [weak self] in
      self?.$navigationCoordinator.withLock { $0.presentedSheet = nil }
    }
    navigationCoordinator.presentedSheet = .curatorSongPicker(picker)
  }

  func qaActionTapped() {
    guard canEditContent else { return }
    let picker = AMAQuestionPickerPageModel(
      stationId: stationId, showStartedAt: nil,
      addToShow: { [weak self] questionAnswer in
        guard let self else { throw CancellationError() }
        let blockIds =
          [questionAnswer.questionBlock.id, questionAnswer.answerBlock.id]
          + [questionAnswer.trailingBlock?.id].compactMap { $0 }
        if let failure = await appendToShow(blockIds, alertsOnFailure: false).value {
          throw failure
        }
      })
    navigationCoordinator.push(.amaQuestionPickerPage(picker))
  }

  func segmentsMoved(from source: IndexSet, to destination: Int) async {
    guard canReorder, let episode, let sourceIndex = source.first else { return }
    let ordered = orderedSegments
    guard ordered.indices.contains(sourceIndex) else { return }
    let segmentId = ordered[sourceIndex].id
    let finalIndex = destination > sourceIndex ? destination - 1 : destination
    var reordered = ordered
    reordered.move(fromOffsets: source, toOffset: destination)
    self.episode = episode.replacingSegments(reordered)
    _ = await enqueueSave { [weak self, api] jwt, episodeId in
      do {
        self?.episode = try await api.moveEpisodeSegment(jwt, episodeId, segmentId, finalIndex)
      } catch {
        self?.episode = episode
        throw error
      }
    }.value
  }

  func segmentDeleteTapped(_ segmentId: String) async {
    guard canEditContent else { return }
    _ = await enqueueSave { [weak self, api] jwt, episodeId in
      self?.episode = try await api.removeEpisodeSegment(jwt, episodeId, segmentId)
    }.value
  }

  func scheduleButtonTapped() {}

  func changeTimeButtonTapped() {}

  func unscheduleButtonTapped() {}

  func seriesRowTapped() {}

  // MARK: - View Helpers

  var state: CuratorEpisodeState {
    guard let episode else { return .draft }
    let state = episode.state(now: now, lockMS: settings?.airingEditLockMS ?? .max)
    if refusedAsLocked, case .scheduled(let airing) = state { return .locked(airing) }
    return state
  }

  var isReadOnly: Bool { episode?.isMultiAiring ?? false }

  var canEditContent: Bool {
    switch state {
    case .draft, .scheduled: return canRename
    case .locked, .aired: return false
    }
  }

  var canReorder: Bool { canEditContent && pendingSaveCount == 0 }

  var canRename: Bool { !isAwaitingFirstLoad && !isReadOnly }

  var canChangeSeries: Bool { canRename }

  var addCardOpacity: Double { canEditContent ? 1 : 0 }

  var draftBadges: [String] {
    guard case .draft = state else { return [] }
    return ["draft"]
  }

  var calendarBadges: IdentifiedArrayOf<ShowBuilderCalendarBadge> {
    guard let airing = state.airing else { return [] }
    return IdentifiedArray(
      uniqueElements: [ShowBuilderCalendarBadge(date: airing.airtime, timeZone: timeZone)])
  }

  var headline: String {
    switch state {
    case .draft: return "Not scheduled yet"
    case .scheduled(let airing), .locked(let airing):
      return "\(formatted(airing.airtime, "EEEE, MMM d")) \u{00B7} "
        + formatted(airing.airtime, "h:mm a")
    case .aired: return "Already aired"
    }
  }

  var headlineColor: Color {
    guard case .draft = state else { return .playolaTextPrimary }
    return .playolaWarningAmber
  }

  var statusLine: String {
    let detail: String?
    switch state {
    case .draft, .scheduled: detail = "Changes save automatically"
    case .locked(let airing):
      detail =
        now >= (airing.startTime ?? airing.airtime)
        ? "On air now" : "Airs at about \(formatted(airing.airtime, "h:mm a")) \u{00B7} locked"
    case .aired: detail = nil
    }
    return [lengthLabel, detail].compactMap { $0 }.joined(separator: " \u{00B7} ")
  }

  var changeTimeButtons: [String] {
    guard !isReadOnly, case .scheduled = state else { return [] }
    return [changeTimeButtonTitle]
  }

  var seriesTitle: String {
    guard let series = episode?.show, !series.isOneTime else { return "Add to a series" }
    return series.title
  }

  var seriesActionText: String {
    guard let series = episode?.show, !series.isOneTime else { return "Optional" }
    return "Change"
  }

  var seriesActionColor: Color {
    guard let series = episode?.show, !series.isOneTime else { return .playolaTextSecondary }
    return .playolaRed
  }

  var lockLines: [String] {
    guard !isReadOnly, case .scheduled(let airing) = state, let settings else { return [] }
    let lockStart = airing.airtime.addingTimeInterval(-Double(settings.airingEditLockMS) / 1000)
    return [
      "You can make changes until \(formatted(lockStart, "EEE, MMM d")) at "
        + formatted(lockStart, "h:mm a")
    ]
  }

  var lockedBanners: IdentifiedArrayOf<ShowBuilderBanner> {
    guard !isReadOnly, case .locked = state else { return [] }
    let reason =
      settings.map { "Shows lock \(Self.lockLength($0.airingEditLockMS)) before they air." }
      ?? "This show is locked because it airs soon."
    return IdentifiedArray(uniqueElements: [
      ShowBuilderBanner(
        title: "Locked",
        message: reason + " You can still rename it, change its series, or unschedule it.")
    ])
  }

  var readOnlyNotices: [String] {
    guard isReadOnly else { return [] }
    return ["This show airs more than once, so it can only be changed on the web."]
  }

  var totalDurationText: String { Self.clockText(episode?.durationMS ?? 0) }

  var rows: IdentifiedArrayOf<ShowBuilderSegmentRow> {
    let isEditable = canEditContent
    return IdentifiedArray(
      uniqueElements: orderedSegments.map { segment in
        ShowBuilderSegmentRow(
          id: segment.id, data: Self.rowData(for: segment, isEditable: isEditable))
      })
  }

  var scheduleButtons: [String] {
    guard !isReadOnly, case .draft = state else { return [] }
    return ["Schedule"]
  }

  var unscheduleButtons: [String] {
    guard !isReadOnly, state.airing != nil else { return [] }
    return ["Unschedule"]
  }

  // MARK: - Private Helpers

  private static let unknownRowDataId = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

  private var timeZone: TimeZone {
    settings?.timeZone
      ?? TimeZone(identifier: StationSchedulingSettings.fallbackTimeZoneIdentifier) ?? .gmt
  }

  private var isAwaitingFirstLoad: Bool { episodeId != nil && episode == nil }

  private var orderedSegments: [CuratorEpisodeSegment] {
    (episode?.segments ?? []).sorted { $0.position < $1.position }
  }

  private var addedSongIds: Set<String> {
    Set(orderedSegments.compactMap(\.audioBlock).filter { $0.type == "song" }.map(\.id))
  }

  private var lengthLabel: String? {
    guard let episode, episode.hasAudio else { return nil }
    return "\(Int((Double(episode.durationMS) / 60_000).rounded())) min"
  }

  @discardableResult
  private func appendToShow(_ audioBlockIds: [String], alertsOnFailure: Bool = true)
    -> Task<(any Error)?, Never>
  {
    enqueueSave(alertsOnFailure: alertsOnFailure) { [weak self, api] jwt, episodeId in
      let position = self?.episode?.segments.count ?? 0
      self?.episode = try await api.addEpisodeSegments(jwt, episodeId, audioBlockIds, position)
    }
  }

  private func appendVoicetrackToShow(_ audioBlockId: String) async {
    guard let failure = await appendToShow([audioBlockId], alertsOnFailure: false).value else {
      return
    }
    guard !isCancellation(failure) else { return }
    presentedAlert = PlayolaAlert(
      title: "Couldn’t Add Voicetrack",
      message: failure.localizedDescription,
      primaryButtonText: "Retry",
      primaryAction: { [weak self] in await self?.appendVoicetrackToShow(audioBlockId) },
      secondaryButtonText: "Cancel")
  }

  private func enqueue(
    _ operation: @escaping @MainActor () async -> (any Error)?
  ) -> Task<(any Error)?, Never> {
    let previous = lastOperation
    let task = Task {
      _ = await previous?.value
      return await operation()
    }
    lastOperation = task
    return task
  }

  private func enqueueSave(
    alertsOnFailure: Bool = true,
    _ change: @escaping @MainActor (_ jwt: String, _ episodeId: String) async throws -> Void
  ) -> Task<(any Error)?, Never> {
    pendingSaveCount += 1
    return enqueue { [self] in
      defer { pendingSaveCount -= 1 }
      let failure = await runChange(change)
      if alertsOnFailure, let failure { presentSaveAlert(for: failure) }
      return failure
    }
  }

  private func runChange(
    _ change: @MainActor (_ jwt: String, _ episodeId: String) async throws -> Void
  ) async -> (any Error)? {
    var failure: (any Error)?
    do {
      guard let jwt = auth.jwt else { throw ShowBuilderNotSignedIn() }
      let id = try await resolveEpisodeId(jwt: jwt)
      try await change(jwt, id)
    } catch {
      failure = error
      await recordSaveFailure(error)
    }
    await loadEpisode(showsToastOnFailure: false)
    return failure
  }

  private func resolveEpisodeId(jwt: String) async throws -> String {
    if let episodeId { return episodeId }
    let created =
      if let seriesId {
        try await api.createEpisodeInSeries(jwt, seriesId, Self.newShowTitle)
      } else {
        try await api.createStandaloneEpisode(jwt, stationId, Self.newShowTitle)
      }
    episodeId = created.id
    episode = created
    return created.id
  }

  private func loadEpisode(showsToastOnFailure: Bool) async {
    guard let jwt = auth.jwt, let episodeId else { return }
    do {
      episode = try await api.getCuratorEpisode(jwt, episodeId)
    } catch {
      guard !isCancellation(error) else { return }
      await report(error, endpoint: "getCuratorEpisode")
      guard showsToastOnFailure else { return }
      await toast.show(PlayolaToast(message: "This show couldn\u{2019}t load.", buttonTitle: "OK"))
    }
  }

  private func loadSettings(jwt: String) async {
    do {
      settings = try await api.getStationSchedulingSettings(jwt, stationId)
    } catch {
      guard !isCancellation(error) else { return }
      await report(error, endpoint: "getStationSchedulingSettings")
      await toast.show(PlayolaToast(message: settingsLoadErrorMessage, buttonTitle: "OK"))
    }
  }

  private func recordSaveFailure(_ error: Error) async {
    guard !isCancellation(error), !(error is ShowBuilderNotSignedIn) else { return }
    if case APIError.recordedShowLocked = error { refusedAsLocked = true }
    await report(error, endpoint: "showBuilderSave")
  }

  private func presentSaveAlert(for error: Error) {
    guard !isCancellation(error) else { return }
    let title =
      switch error {
      case is ShowBuilderNotSignedIn: "Not Signed In"
      case APIError.recordedShowLocked: "Show Locked"
      default: "Couldn\u{2019}t Save"
      }
    presentedAlert = Self.alert(title: title, message: error.localizedDescription)
  }

  private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }

  private func report(_ error: Error, endpoint: String) async {
    guard !NetworkErrorClassifier.isNetworkError(error) else { return }
    var tags = NetworkErrorClassifier.errorTags(for: error)
    tags["endpoint"] = endpoint
    await errorReporting.reportError(error, tags)
  }

  private func formatted(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private static func alert(title: String, message: String) -> PlayolaAlert {
    PlayolaAlert(title: title, message: message, dismissButton: .cancel(Text("OK")))
  }

  private static func lockLength(_ milliseconds: Int) -> String {
    let minutes = milliseconds / 60_000
    guard minutes % 60 == 0 else { return minutes == 1 ? "1 minute" : "\(minutes) minutes" }
    let hours = minutes / 60
    return hours == 1 ? "1 hour" : "\(hours) hours"
  }

  private static func clockText(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private static func rowData(for segment: CuratorEpisodeSegment, isEditable: Bool)
    -> AMAOpeningRowData
  {
    let dataId = UUID(uuidString: segment.id) ?? unknownRowDataId
    let trailingIcon = isEditable ? "line.3.horizontal" : "lock"
    guard let block = segment.audioBlock else {
      return AMAOpeningRowData(
        id: dataId, title: "Song request", subtitle: "Waiting for the song",
        subtitleColor: .playolaTextDisabled, iconSystemName: "music.note", albumImageUrl: nil,
        leadingArtworkOpacity: 0, leadingFallbackOpacity: 1, trailingText: "",
        trailingIconSystemName: trailingIcon, processingOpacity: 0, completedOpacity: 1,
        isEditable: isEditable)
    }
    let isSong = block.type == "song"
    let hasArtwork = isSong && block.imageUrl != nil
    return AMAOpeningRowData(
      id: dataId, title: block.title, subtitle: isSong ? block.artist : "Your voice",
      subtitleColor: .playolaTextDisabled, iconSystemName: isSong ? "music.note" : "mic",
      albumImageUrl: isSong ? block.imageUrl : nil, leadingArtworkOpacity: hasArtwork ? 1 : 0,
      leadingFallbackOpacity: hasArtwork ? 0 : 1, trailingText: clockText(block.durationMS),
      trailingIconSystemName: trailingIcon, processingOpacity: 0, completedOpacity: 1,
      isEditable: isEditable)
  }
}

extension CuratorEpisodeState {
  fileprivate var airing: CuratorAiring? {
    switch self {
    case .scheduled(let airing), .locked(let airing): return airing
    case .draft, .aired: return nil
    }
  }
}

extension CuratorEpisode {
  fileprivate func mergingMetadata(from updated: CuratorEpisode) -> CuratorEpisode {
    CuratorEpisode(
      id: updated.id, showId: updated.showId, title: updated.title,
      durationMS: updated.durationMS, show: updated.show, segments: segments, airings: airings)
  }

  fileprivate func replacingSegments(_ ordered: [CuratorEpisodeSegment]) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: showId, title: title, durationMS: durationMS, show: show,
      segments: ordered.enumerated().map { index, segment in
        CuratorEpisodeSegment(
          id: segment.id, position: index, offsetMS: segment.offsetMS,
          audioBlock: segment.audioBlock)
      },
      airings: airings)
  }
}
