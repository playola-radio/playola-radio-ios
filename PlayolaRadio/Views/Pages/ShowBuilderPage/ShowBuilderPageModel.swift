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
  let segmentIds: [String]
  let title: String
  let subtitle: String
  let icon: String
  let tileColor: Color
  let artworkURL: URL?
  let durationText: String
  let handleIcons: [String]
  let isEditable: Bool
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
  @ObservationIgnored @Dependency(\.notificationCenter) var notificationCenter
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
  var isSavingSeries = false
  private var pendingSaveCount = 0
  private var questionAnswerRoles: [String: QuestionAnswerRole] = [:]
  private var pendingAudioAdds: [[String]: [String]] = [:]
  private var scheduleNeedsRefresh = false
  private var initialLoadNoticeShown = false
  @ObservationIgnored private var lastOperation: Task<(any Error)?, Never>?
  @ObservationIgnored private var seriesSheetsAreOpen = false
  @ObservationIgnored private var finishedSeriesChange: FinishedSeriesChange?

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
  var questionAnswerRowTitle: String { "Question and Answer" }
  var questionAnswerRowSubtitle: String { "Question + answer" }
  var questionRowTitle: String { "Question" }
  var answerRowTitle: String { "Answer" }
  var voiceRowSubtitle: String { "Your voice" }
  var unknownAskerRowSubtitle: String { "Listener question" }
  var songRequestRowTitle: String { "Song request" }
  var songRequestRowSubtitle: String { "Waiting for the song" }
  var settingsLoadErrorMessage: String { "The show settings couldn’t load." }
  var airingsLoadErrorMessage: String { "Open slots couldn’t load." }
  var emptyShowAlertTitle: String { "Nothing to Schedule Yet" }
  var emptyShowAlertMessage: String { "Add a voicetrack, a song or a Q/A before scheduling it." }
  var loadingOpacity: Double { isLoading ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let jwt = auth.jwt else { return }
    initialLoadNoticeShown = false
    async let settingsLoad: Bool = loadSettings(jwt: jwt, coalesceNotice: true)
    async let questionsLoad: Bool = loadQuestionAnswerRoles(jwt: jwt)
    var episodeLoaded = true
    if episodeId != nil, episode == nil || scheduleNeedsRefresh {
      isLoading = true
      defer { isLoading = false }
      _ = await enqueue { [self] in
        episodeLoaded = await loadEpisode(showsToastOnFailure: true)
        return nil
      }.value
    }
    let settingsLoaded = await settingsLoad
    let questionsLoaded = await questionsLoad
    if !questionsLoaded, settingsLoaded, episodeLoaded {
      await showInitialLoadNotice("Question details couldn’t load.")
    }
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
        recordQuestionAnswerRoles(questionAnswer)
        let blockIds =
          [questionAnswer.questionBlock.id, questionAnswer.answerBlock.id]
          + [questionAnswer.trailingBlock?.id].compactMap { $0 }
        if let failure = await appendToShow(blockIds, alertsOnFailure: false).value {
          throw failure
        }
      })
    navigationCoordinator.push(.amaQuestionPickerPage(picker))
  }

  func rowsMoved(from source: IndexSet, to destination: Int) async {
    guard canReorder, let episode, source.count == 1, let sourceIndex = source.first else { return }
    let groups = segmentGroups
    guard groups.indices.contains(sourceIndex) else { return }
    var reorderedGroups = groups
    reorderedGroups.move(fromOffsets: source, toOffset: destination)
    let movedIds = groups[sourceIndex].map(\.id)
    let newGroupIndex = destination > sourceIndex ? destination - 1 : destination
    let oldStart = groups[..<sourceIndex].reduce(0) { $0 + $1.count }
    let newStart = reorderedGroups[..<newGroupIndex].reduce(0) { $0 + $1.count }
    let moves = movedIds.enumerated().map { offset, segmentId in
      (segmentId, newStart < oldStart ? newStart + offset : newStart + movedIds.count - 1)
    }
    self.episode = episode.replacingSegments(reorderedGroups.flatMap { $0 })
    _ = await enqueueSave { [weak self, api] jwt, episodeId in
      var updated = episode
      defer { self?.episode = updated }
      for (segmentId, finalIndex) in moves {
        updated = try await api.moveEpisodeSegment(jwt, episodeId, segmentId, finalIndex)
      }
    }.value
  }

  func rowDeleteTapped(_ rowId: String) async {
    guard canEditContent, let segmentIds = rows[id: rowId]?.segmentIds else { return }
    _ = await enqueueSave { [weak self, api] jwt, episodeId in
      var updated = self?.episode
      defer { self?.episode = updated }
      if segmentIds.count > 1, let self, case .scheduled = state,
        !orderedSegments.contains(where: { !segmentIds.contains($0.id) && $0.audioBlock != nil })
      {
        throw APIError.serverError("Unschedule this show before removing its last audio.")
      }
      for segmentId in segmentIds {
        updated = try await api.removeEpisodeSegment(jwt, episodeId, segmentId)
      }
    }.value
  }

  func scheduleButtonTapped() async {
    await presentScheduleSheet()
  }

  func changeTimeButtonTapped() async {
    await presentScheduleSheet()
  }

  func unscheduleButtonTapped() async {
    guard !scheduleNeedsRefresh, !isReadOnly, let airing = state.airing, let episode,
      let settings = await resolvedSettings()
    else { return }
    let sheet = UnscheduleShowSheetModel(
      episode: episode, airing: airing, series: episode.show, settings: settings,
      unschedule: { [weak self] in try await self?.unschedule(airing) }
    )
    navigationCoordinator.presentedSheet = .unscheduleShow(sheet)
  }

  func seriesRowTapped() {
    guard canChangeSeries else { return }
    let picker = withDependencies(from: self) {
      SeriesPickerSheetModel(
        stationId: stationId, showTitle: navigationTitle, currentSeries: episode?.show,
        timeZone: timeZone)
    }
    picker.onSeriesChange = { [weak self] change in await self?.seriesChangeCommitted(change) }
    picker.onDismissed = { [weak self] in self?.seriesSheetsDismissed() }
    seriesSheetsAreOpen = true
    $navigationCoordinator.withLock { $0.presentedSheet = .seriesPicker(picker) }
  }

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

  var canChangeSeries: Bool { canRename && !isSavingSeries }

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
    guard !scheduleNeedsRefresh, !isReadOnly, case .scheduled = state else { return [] }
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

  var seriesTitleColor: Color {
    guard let series = episode?.show, !series.isOneTime else { return .playolaTextSecondary }
    return .playolaTextPrimary
  }

  var seriesActionColor: Color {
    guard let series = episode?.show, !series.isOneTime else { return .playolaTextQuaternary }
    return .playolaRed
  }

  var seriesRowOutlineColor: Color {
    guard let series = episode?.show, !series.isOneTime else {
      return .playolaSurfaceArtPlaceholder
    }
    return .playolaSurfaceControl
  }

  var seriesActionFontName: String {
    guard let series = episode?.show, !series.isOneTime else { return FontNames.Inter_400_Regular }
    return FontNames.Inter_600_SemiBold
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
      settings.map { "Shows lock \($0.airingEditLockText) before they air." }
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
      uniqueElements: segmentGroups.map { row(for: $0, isEditable: isEditable) })
  }

  var scheduleButtons: [String] {
    guard !scheduleNeedsRefresh, !isReadOnly, case .draft = state else { return [] }
    return ["Schedule"]
  }

  var unscheduleButtons: [String] {
    guard !scheduleNeedsRefresh, !isReadOnly, state.airing != nil else { return [] }
    return ["Unschedule"]
  }

  // MARK: - Private Helpers

  private struct FinishedSeriesChange {
    let failure: (any Error)?
  }

  private enum QuestionAnswerRole {
    case question(askerFirstName: String?, answerAudioBlockId: String?)
    case answer
  }

  private static let unknownListenerName = "Listener"
  private static let songIcon = "AMA-music"
  private static let voiceIcon = "AMA-mic"
  private static let questionAnswerIcon = "AMA-messages-square"
  private static let dragHandleIcon = "AMA-menu"

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

  private var segmentGroups: [[CuratorEpisodeSegment]] {
    var groups: [[CuratorEpisodeSegment]] = []
    for segment in orderedSegments {
      if let previous = groups.last, previous.count == 1,
        let questionBlockId = previous[0].audioBlock?.id,
        case .question(_, let answerAudioBlockId?) = questionAnswerRoles[questionBlockId],
        segment.audioBlock?.id == answerAudioBlockId
      {
        groups[groups.count - 1].append(segment)
      } else {
        groups.append([segment])
      }
    }
    return groups
  }

  private var lengthLabel: String? { episode?.lengthLabel }

  @discardableResult
  private func appendToShow(_ audioBlockIds: [String], alertsOnFailure: Bool = true)
    -> Task<(any Error)?, Never>
  {
    enqueueSave(alertsOnFailure: alertsOnFailure) { [weak self, api] jwt, episodeId in
      guard let self else { throw CancellationError() }
      if let previousIds = pendingAudioAdds[audioBlockIds] {
        guard await loadEpisode(showsToastOnFailure: false) else { throw APIError.dataNotValid }
        let added = orderedSegments.filter { !previousIds.contains($0.id) }.compactMap {
          $0.audioBlock?.id
        }
        if added.indices.contains(where: { added[$0...].starts(with: audioBlockIds) }) {
          pendingAudioAdds[audioBlockIds] = nil
          return
        }
      }
      let position = orderedSegments.count
      pendingAudioAdds[audioBlockIds] = orderedSegments.map(\.id)
      episode = try await api.addEpisodeSegments(jwt, episodeId, audioBlockIds, position)
      pendingAudioAdds[audioBlockIds] = nil
    }
  }

  private func presentScheduleSheet() async {
    guard !scheduleNeedsRefresh, !isReadOnly else { return }
    guard let episode, episode.hasAudio else {
      presentedAlert = Self.alert(title: emptyShowAlertTitle, message: emptyShowAlertMessage)
      return
    }
    guard let settings = await resolvedSettings() else { return }
    let hasSlotSuggestions = episode.show.map { !$0.isOneTime && $0.rrule != nil } ?? false
    let intervals: [DateInterval]
    if hasSlotSuggestions {
      guard let loadedIntervals = await loadOccupiedIntervals(excluding: episode.id) else { return }
      intervals = loadedIntervals
    } else {
      intervals = []
    }
    let sheet = withDependencies(from: self) {
      ScheduleShowSheetModel(
        episode: episode, series: episode.show, settings: settings, occupiedIntervals: intervals,
        initialTime: state.airing?.airtime ?? slot,
        schedule: { [weak self] airtime in try await self?.schedule(at: airtime) })
    }
    navigationCoordinator.presentedSheet = .scheduleShow(sheet)
  }

  private func resolvedSettings() async -> StationSchedulingSettings? {
    if settings == nil, let jwt = auth.jwt { await loadSettings(jwt: jwt) }
    return settings
  }

  private func loadOccupiedIntervals(excluding episodeId: String) async -> [DateInterval]? {
    guard let jwt = auth.jwt else { return nil }
    do {
      let airings = try await api.getAirings(jwt, stationId)
      return occupiedIntervals(from: airings, excludingEpisodeId: episodeId)
    } catch {
      guard !isCancellation(error) else { return nil }
      await report(error, endpoint: "getAirings")
      await toast.show(PlayolaToast(message: airingsLoadErrorMessage, buttonTitle: "OK"))
      return nil
    }
  }

  private func schedule(at airtime: Date) async throws {
    let failure = await enqueueSave(alertsOnFailure: false) {
      [weak self, api, stationId] jwt, episodeId in
      guard let self else { throw CancellationError() }
      if scheduleNeedsRefresh, !(await loadEpisode(showsToastOnFailure: false)) {
        throw APIError.dataNotValid
      }
      if let airing = state.airing, airing.airtime == airtime { return }
      scheduleNeedsRefresh = true
      if let airing = state.airing {
        try await api.moveAiring(jwt, airing.id, airtime)
      } else {
        try await api.scheduleEpisode(jwt, episodeId, stationId, airtime)
      }
    }.value
    if let failure { throw failure }
    if scheduleNeedsRefresh { throw APIError.dataNotValid }
  }

  private func unschedule(_ airing: CuratorAiring) async throws {
    let failure = await enqueueSave(alertsOnFailure: false) { [weak self, api] jwt, _ in
      guard let self else { throw CancellationError() }
      if scheduleNeedsRefresh, !(await loadEpisode(showsToastOnFailure: false)) {
        throw APIError.dataNotValid
      }
      guard state.airing?.id == airing.id else { return }
      scheduleNeedsRefresh = true
      try await api.unscheduleAiring(jwt, airing.id)
      refusedAsLocked = false
    }.value
    if let failure { throw failure }
    if scheduleNeedsRefresh { throw APIError.dataNotValid }
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
      if failure == nil {
        notificationCenter.post(
          name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
      }
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

  @discardableResult
  private func loadEpisode(showsToastOnFailure: Bool) async -> Bool {
    guard let jwt = auth.jwt, let episodeId else { return false }
    do {
      episode = try await api.getCuratorEpisode(jwt, episodeId)
      scheduleNeedsRefresh = false
      return true
    } catch {
      guard !isCancellation(error) else { return false }
      await report(error, endpoint: "getCuratorEpisode")
      if showsToastOnFailure {
        await showInitialLoadNotice("This show couldn\u{2019}t load.")
      }
      return false
    }
  }

  @discardableResult
  private func loadSettings(jwt: String, coalesceNotice: Bool = false) async -> Bool {
    do {
      settings = try await api.getStationSchedulingSettings(jwt, stationId)
      return true
    } catch {
      guard !isCancellation(error) else { return false }
      await report(error, endpoint: "getStationSchedulingSettings")
      if coalesceNotice {
        await showInitialLoadNotice(settingsLoadErrorMessage)
      } else {
        await toast.show(PlayolaToast(message: settingsLoadErrorMessage, buttonTitle: "OK"))
      }
      return false
    }
  }

  private func showInitialLoadNotice(_ message: String) async {
    guard !initialLoadNoticeShown else { return }
    initialLoadNoticeShown = true
    await toast.show(PlayolaToast(message: message, buttonTitle: "OK"))
  }

  private func loadQuestionAnswerRoles(jwt: String) async -> Bool {
    do {
      let questions = try await api.getListenerQuestions(jwt, stationId)
      for question in questions {
        questionAnswerRoles[question.audioBlockId] = .question(
          askerFirstName: question.listener?.firstName,
          answerAudioBlockId: question.answerAudioBlockId)
        if let answerId = question.answerAudioBlockId {
          questionAnswerRoles[answerId] = .answer
        }
      }
      return true
    } catch {
      guard !isCancellation(error) else { return true }
      await report(error, endpoint: "getListenerQuestions")
      return false
    }
  }

  private func recordQuestionAnswerRoles(_ questionAnswer: AMAQuestionAnswer) {
    let askerFirstName =
      questionAnswer.listenerName == Self.unknownListenerName ? nil : questionAnswer.listenerName
    questionAnswerRoles[questionAnswer.questionBlock.id] = .question(
      askerFirstName: askerFirstName, answerAudioBlockId: questionAnswer.answerBlock.id)
    questionAnswerRoles[questionAnswer.answerBlock.id] = .answer
  }

  private func recordSaveFailure(_ error: Error) async {
    guard !isCancellation(error), !(error is ShowBuilderNotSignedIn) else { return }
    if case APIError.recordedShowLocked = error { refusedAsLocked = true }
    await report(error, endpoint: "showBuilderSave")
  }

  private func seriesChangeCommitted(_ change: SeriesChange) async {
    isSavingSeries = true
    let failure = await enqueueSave(alertsOnFailure: false) { [weak self, api] jwt, episodeId in
      let updated = try await api.updateEpisode(
        jwt, episodeId, CuratorEpisodeUpdate(series: change))
      self?.episode = self?.episode?.mergingMetadata(from: updated) ?? updated
    }.value
    finishedSeriesChange = FinishedSeriesChange(failure: failure)
    finishSeriesChangeIfSettled()
  }

  private func seriesSheetsDismissed() {
    seriesSheetsAreOpen = false
    finishSeriesChangeIfSettled()
  }

  private func finishSeriesChangeIfSettled() {
    guard !seriesSheetsAreOpen, let finished = finishedSeriesChange else { return }
    finishedSeriesChange = nil
    isSavingSeries = false
    if let failure = finished.failure { presentSaveAlert(for: failure) }
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

  private static func clockText(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func row(for group: [CuratorEpisodeSegment], isEditable: Bool)
    -> ShowBuilderSegmentRow
  {
    func makeRow(
      _ title: String, _ subtitle: String, icon: String, tileColor: Color,
      artworkURL: URL? = nil
    ) -> ShowBuilderSegmentRow {
      let blocks = group.compactMap(\.audioBlock)
      return ShowBuilderSegmentRow(
        id: group[0].id, segmentIds: group.map(\.id), title: title, subtitle: subtitle,
        icon: icon, tileColor: tileColor, artworkURL: artworkURL,
        durationText: blocks.isEmpty ? "" : Self.clockText(blocks.reduce(0) { $0 + $1.durationMS }),
        handleIcons: isEditable ? [Self.dragHandleIcon] : [], isEditable: isEditable)
    }
    guard let block = group[0].audioBlock else {
      return makeRow(
        songRequestRowTitle, songRequestRowSubtitle, icon: Self.songIcon,
        tileColor: .playolaSurfaceMuted)
    }
    switch questionAnswerRoles[block.id] {
    case .question(let askerFirstName, _) where group.count == 2:
      return makeRow(
        askerFirstName.map { "\(questionAnswerRowTitle): \($0)" } ?? questionAnswerRowTitle,
        questionAnswerRowSubtitle, icon: Self.questionAnswerIcon, tileColor: .playolaRed)
    case .question(let askerFirstName, _):
      return makeRow(
        questionRowTitle, askerFirstName.map { "From \($0)" } ?? unknownAskerRowSubtitle,
        icon: Self.questionAnswerIcon, tileColor: .playolaRed)
    case .answer:
      return makeRow(
        answerRowTitle, voiceRowSubtitle, icon: Self.questionAnswerIcon, tileColor: .playolaRed)
    case nil where block.type == "song":
      return makeRow(
        block.title, block.artist, icon: Self.songIcon, tileColor: .playolaSurfaceMuted,
        artworkURL: block.imageUrl)
    case nil:
      return makeRow(block.title, voiceRowSubtitle, icon: Self.voiceIcon, tileColor: .playolaRed)
    }
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
