//
//  BroadcastPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import Combine
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

struct DependencyDateProvider: DateProviderProtocol {
  @Dependency(\.date.now) var currentDate

  func now() -> Date {
    currentDate
  }
}

@MainActor
@Observable
class BroadcastPageModel: ViewModel {
  let stationId: String
  var liveShowId: String? {
    didSet {
      if liveShowId != oldValue { reorderedSpinIds = nil }
    }
  }
  // AMA reveals scheduled fallback audio without changing its server-side filler status.
  var visibleFillerIds: Set<String> = []
  private let providedStationName: String?
  private var fetchedStationName: String?
  var schedule: Schedule?
  var isLoading: Bool = false
  var spinIdsBeingRescheduled: Set<String> = []
  var spinIdsBeingDeleted: Set<String> = []
  var presentedAlert: PlayolaAlert?
  var currentNowPlayingId: String?
  private var reorderedSpinIds: [String]?  // nil means use default order
  var stagingItems: [any StagingItem] = []
  private var stagingIdsBeingInserted: Set<String> = []

  // Notify Listeners state
  var showNotifyListenersSheet: Bool = false
  var notifyMessage: String = ""
  var isSendingNotification: Bool = false

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.toast) var toast
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.lastNotificationSentAt) var lastNotificationSentAt

  var recordPageModel: RecordPageModel?
  var songSearchPageModel: SongSearchPageModel?

  @ObservationIgnored private var scheduleUpdateCancellable: AnyCancellable?

  private let notificationCooldownSeconds: TimeInterval = 12 * 60 * 60

  var canSendNotification: Bool {
    guard let lastSent = lastNotificationSentAt[stationId] else { return true }
    return now.timeIntervalSince(lastSent) >= notificationCooldownSeconds
  }

  var timeUntilNextNotification: TimeInterval? {
    guard let lastSent = lastNotificationSentAt[stationId] else { return nil }
    let elapsed = now.timeIntervalSince(lastSent)
    let remaining = notificationCooldownSeconds - elapsed
    return remaining > 0 ? remaining : nil
  }

  var notificationRestTimeRemainingString: String? {
    guard let seconds = timeUntilNextNotification else { return nil }
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
  }

  var navigationTitle: String {
    providedStationName ?? fetchedStationName ?? "My Station"
  }

  var voiceTrackButtonLabel: String { "VoiceTrack" }
  var addSongButtonLabel: String { "Add Song" }
  var notifyButtonLabel: String { "Notify" }
  var stagingSectionTitle: String { "READY TO PLACE" }
  var liveNowLabel: String { "LIVE NOW" }
  var notifyListenersTitle: String { "Notify Listeners" }
  var notifyListenersPrompt: String { "Tell your listeners you're about to go live." }
  var sendNotificationButtonTitle: String { "Send Notification" }
  var cancelButtonTitle: String { "Cancel" }

  var notifyMessagePlaceholder: String {
    """
    Tell your listeners what you're up to...

    "I'm going live from the van!"
    "Playing my favorite road songs today"
    """
  }

  private static let airtimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter
  }()

  func airtimeLabel(for spin: Spin) -> String {
    let timeString = Self.airtimeFormatter.string(from: spin.airtime).lowercased()
    return "at \(timeString)"
  }

  init(stationId: String, stationName: String? = nil, liveShowId: String? = nil) {
    self.stationId = stationId
    self.liveShowId = liveShowId
    self.providedStationName = stationName
    super.init()
  }

  func viewAppeared(trackScreenView: Bool = true) async {
    startObservingScheduleUpdates()
    if trackScreenView {
      await analytics.track(
        .viewedBroadcastScreen(stationId: stationId, stationName: navigationTitle))
    }
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadSchedule() }
      group.addTask { await self.loadStation() }
    }
  }

  private func startObservingScheduleUpdates() {
    guard scheduleUpdateCancellable == nil else { return }
    let observedStationId = stationId
    scheduleUpdateCancellable = NotificationCenter.default.publisher(
      for: .scheduleUpdated
    )
    .compactMap { notification -> String? in
      guard let id = notification.userInfo?["stationId"] as? String,
        id == observedStationId
      else { return nil }
      return notification.userInfo?["editorName"] as? String
    }
    .sink { [weak self] editorName in
      Task { [weak self] in
        await self?.refreshScheduleFromRemote(editorName: editorName)
      }
    }
  }

  private func loadStation() async {
    guard providedStationName == nil else { return }
    guard let jwt = auth.jwt else { return }
    do {
      if let station = try await api.fetchStation(jwt, stationId) {
        fetchedStationName = station.name
      }
    } catch {
      // Silently fail - we'll just show the default title
    }
  }

  func loadSchedule() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let spins = try await api.fetchSchedule(stationId, true)
      schedule = Schedule(
        stationId: stationId, spins: spins, dateProvider: DependencyDateProvider()
      )
      currentNowPlayingId = nowPlaying?.id
    } catch {
      presentedAlert = .errorLoadingSchedule
    }
  }

  func refreshScheduleFromRemote(editorName: String? = nil) async {
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      withAnimation(.easeInOut(duration: 0.3)) {
        schedule = Schedule(
          stationId: stationId, spins: spins, dateProvider: DependencyDateProvider()
        )
        reorderedSpinIds = nil
        currentNowPlayingId = nowPlaying?.id
      }
      if let editorName {
        await toast.show(
          PlayolaToast(
            message: "Edited by \(editorName)",
            buttonTitle: "OK"
          )
        )
      }
    } catch {
      // Silently fail - user's current view is still valid
    }
  }

  var nowPlaying: Spin? {
    schedule?.nowPlaying()
  }

  var upcomingSpins: [Spin] {
    guard let schedule else { return [] }
    let futureSpins = schedule.current().filter {
      $0.airtime > now
        && !spinIdsBeingDeleted.contains($0.id)
        && (liveShowId == nil
          || ($0.liveShowId == liveShowId
            && ($0.isFiller != true || visibleFillerIds.contains($0.id))))
    }

    // If we have a custom order, use it
    if let orderedIds = reorderedSpinIds {
      let spinDict = Dictionary(uniqueKeysWithValues: futureSpins.map { ($0.id, $0) })
      // Return spins in the custom order, filtering out any that are no longer in futureSpins
      return orderedIds.compactMap { spinDict[$0] }
    }

    return futureSpins
  }

  var spinRows: IdentifiedArrayOf<SpinRow> {
    let spins = upcomingSpins
    var rows: IdentifiedArrayOf<SpinRow> = []
    var index = 0
    while index < spins.count {
      let spin = spins[index]
      guard let groupId = spin.spinGroupId else {
        rows.append(SpinRow(spins: [spin]))
        index += 1
        continue
      }
      var members = [spin]
      var next = index + 1
      while next < spins.count, spins[next].spinGroupId == groupId {
        members.append(spins[next])
        next += 1
      }
      rows.append(SpinRow(spins: members))
      index = next
    }
    return rows
  }

  func isRowDeletable(_ row: SpinRow) -> Bool {
    row.spins.allSatisfy { canDeleteSpin($0) }
  }

  var showEndDropTargets: [String] {
    guard let liveShowId,
      let filler = schedule?.current().first(where: {
        $0.liveShowId == liveShowId && $0.isFiller == true && canDeleteSpin($0)
      })
    else { return [] }
    return [filler.id]
  }

  private var spinBeforeShowQueueId: String? {
    guard liveShowId != nil, let firstShowSpin = upcomingSpins.first,
      let currentSpins = schedule?.current(),
      let firstIndex = currentSpins.firstIndex(where: { $0.id == firstShowSpin.id }), firstIndex > 0
    else { return nil }
    return currentSpins[firstIndex - 1].id
  }

  var showEndDropLabel: String { "Add to end of show" }

  // The spin id a new item should be placed after to land at the end of the live show
  // (just before the reserve filler). Falls back to the last show spin, then `nowPlaying`,
  // then `nil` (front of queue). Pure: performs no mutation or alerting.
  func placeAfterSpinIdForShowEnd() -> String? {
    if let fillerId = showEndDropTargets.first {
      let futureSpins = schedule?.current().filter { $0.airtime > now } ?? []
      if let fillerIndex = futureSpins.firstIndex(where: { $0.id == fillerId }) {
        return fillerIndex == 0 ? nowPlaying?.id : futureSpins[fillerIndex - 1].id
      }
    }
    return upcomingSpins.last?.id ?? nowPlaying?.id
  }

  func stagingItemsDropped(_ items: [String], beforeSpinId: String) -> Bool {
    guard let stagingId = items.first, !stagingIdsBeingInserted.contains(stagingId) else {
      return false
    }
    stagingIdsBeingInserted.insert(stagingId)
    Task { await insertStagingItem(stagingId: stagingId, beforeSpinId: beforeSpinId) }
    return true
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlaying else { return 0 }
    return spin.progress(at: now)
  }

  func canDeleteSpin(_ spin: Spin) -> Bool {
    let twoMinutesFromNow = now.addingTimeInterval(120)
    return spin.airtime > twoMinutesFromNow
  }

  func tick() {
    let newNowPlayingId = nowPlaying?.id
    if newNowPlayingId != currentNowPlayingId {
      currentNowPlayingId = newNowPlayingId
    }
  }

  func onAddVoiceTrackTapped() {
    let model = RecordPageModel()
    model.onRecordingAccepted = { [weak self] url in
      await self?.handleAcceptedRecording(url)
    }
    recordPageModel = model
    mainContainerNavigationCoordinator.presentedSheet = .recordPage(model)
  }

  func handleAcceptedRecording(_ url: URL) async {
    await analytics.track(
      .broadcastVoicetrackRecorded(
        stationId: stationId,
        stationName: navigationTitle
      ))

    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    let timeString = formatter.string(from: now).lowercased()
    let title = "Voice Track \(timeString)"

    let voicetrack = LocalVoicetrack(
      originalURL: url,
      title: title
    )
    stagingItems.append(voicetrack)

    await processVoicetrack(voicetrack)
  }

  private func processVoicetrack(_ voicetrack: LocalVoicetrack) async {
    guard let jwt = auth.jwt else {
      updateVoicetrackStatus(id: voicetrack.id, status: .failed(error: "Not authenticated"))
      return
    }

    do {
      let audioBlock = try await voicetrackUploadService.processVoicetrack(
        voicetrack,
        stationId,
        jwt
      ) { [weak self] status in
        self?.updateVoicetrackStatus(id: voicetrack.id, status: status)
      }
      updateVoicetrackAudioBlockId(id: voicetrack.id, audioBlockId: audioBlock.id)
      await analytics.track(
        .broadcastVoicetrackUploaded(
          stationId: stationId,
          stationName: navigationTitle
        ))
    } catch {
      updateVoicetrackStatus(id: voicetrack.id, status: .failed(error: error.localizedDescription))
      presentedAlert = .voicetrackUploadFailed(error.localizedDescription)
    }
  }

  private func updateVoicetrackStatus(id: UUID, status: LocalVoicetrackStatus) {
    guard
      let index = stagingItems.firstIndex(where: {
        ($0 as? LocalVoicetrack)?.id == id
      })
    else { return }
    guard var voicetrack = stagingItems[index] as? LocalVoicetrack else { return }
    voicetrack.status = status
    stagingItems[index] = voicetrack
  }

  private func updateVoicetrackAudioBlockId(id: UUID, audioBlockId: String) {
    guard
      let index = stagingItems.firstIndex(where: {
        ($0 as? LocalVoicetrack)?.id == id
      })
    else { return }
    guard var voicetrack = stagingItems[index] as? LocalVoicetrack else { return }
    voicetrack.audioBlockId = audioBlockId
    stagingItems[index] = voicetrack
  }

  func onAddSongTapped() async {
    await analytics.track(
      .broadcastSongSearchTapped(
        stationId: stationId,
        stationName: navigationTitle
      ))
    let model = SongSearchPageModel(searchMode: .all)
    model.onDismiss = { [weak self] in
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    model.onSongSelected = { [weak self] audioBlock in
      Task { await self?.addSongToStaging(audioBlock) }
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    songSearchPageModel = model
    mainContainerNavigationCoordinator.presentedSheet = .songSearchPage(model)
  }

  func addSongToStaging(_ audioBlock: AudioBlock) async {
    guard !stagingItems.contains(where: { $0.stagingId == audioBlock.id }) else { return }
    stagingItems.append(audioBlock)
    await analytics.track(
      .broadcastSongAdded(
        stationId: stationId,
        stationName: navigationTitle,
        songTitle: audioBlock.title,
        artistName: audioBlock.artist
      ))
  }

  func onNotifyListenersTapped() {
    showNotifyListenersSheet = true
  }

  func cancelNotifyListeners() {
    showNotifyListenersSheet = false
    notifyMessage = ""
  }

  func sendNotification() async {
    guard let jwt = auth.jwt else { return }
    guard !notifyMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    isSendingNotification = true
    defer { isSendingNotification = false }

    let messageLength = notifyMessage.count

    do {
      try await api.sendStationNotification(jwt, stationId, notifyMessage)
      $lastNotificationSentAt.withLock { $0[stationId] = now }
      await analytics.track(
        .broadcastNotificationSent(
          stationId: stationId,
          stationName: navigationTitle,
          messageLength: messageLength
        ))
      showNotifyListenersSheet = false
      notifyMessage = ""
    } catch {
      presentedAlert = .notificationSendFailed(error.localizedDescription)
    }
  }

  // Returns the spins at/after the insertion point, and the id of the spin the new item
  // should be placed after. Returns nil (with an alert/log already handled) if not insertable.
  private func placementForInsertingStagingItem(beforeSpinId: String) -> (
    futureSpins: [Spin], placeAfterSpinId: String
  )? {
    let futureSpins =
      liveShowId == nil
      ? upcomingSpins : schedule?.current().filter { $0.airtime > now } ?? []
    guard let beforeIndex = futureSpins.firstIndex(where: { $0.id == beforeSpinId }) else {
      print("insertStagingItem: Target spin not found: \(beforeSpinId)")
      return nil
    }

    if beforeIndex == 0 {
      guard let nowPlayingId = nowPlaying?.id else {
        print("insertStagingItem: Cannot insert before first spin (no nowPlaying to place after)")
        presentedAlert = .cannotInsertBeforeFirstSpin
        return nil
      }
      return (futureSpins, nowPlayingId)
    }
    return (futureSpins, futureSpins[beforeIndex - 1].id)
  }

  func insertStagingItem(stagingId: String, beforeSpinId: String) async {
    defer { stagingIdsBeingInserted.remove(stagingId) }

    guard let jwt = auth.jwt else {
      print("insertStagingItem: No JWT")
      return
    }

    guard let stagingItem = stagingItems.first(where: { $0.stagingId == stagingId }) else {
      print("insertStagingItem: Item not found in staging")
      return
    }

    guard let audioBlockId = stagingItem.audioBlockId else {
      print("insertStagingItem: Item has no audioBlockId (upload may not be complete)")
      return
    }

    guard
      let (futureSpins, placeAfterSpinId) = placementForInsertingStagingItem(
        beforeSpinId: beforeSpinId)
    else { return }

    let beforeIndex = futureSpins.firstIndex(where: { $0.id == beforeSpinId }) ?? 0
    spinIdsBeingRescheduled = Set(futureSpins[beforeIndex...].map(\.id))
    defer { spinIdsBeingRescheduled = [] }

    let expectedShowId = liveShowId
    do {
      let newSpins = try await api.insertSpin(jwt, audioBlockId, placeAfterSpinId)
      guard liveShowId == expectedShowId else { return }
      withAnimation(.easeInOut(duration: 0.3)) {
        schedule = Schedule(
          stationId: stationId,
          spins: newSpins,
          dateProvider: DependencyDateProvider()
        )
        reorderedSpinIds = nil
        currentNowPlayingId = nowPlaying?.id

        // Remove from staging
        stagingItems.removeAll { $0.stagingId == stagingId }
      }
    } catch {
      guard liveShowId == expectedShowId else { return }
      presentedAlert = .errorInsertingSpin(error.localizedDescription)
    }
  }

  /// Airs an answered listener question by posting the Q&A pair (`listenerQuestionId`) to the
  /// spins endpoint and applying the returned playlist. The server folds in the answer and any
  /// permanent trailing song. Throws `CancellationError` if the live show changed out from under
  /// the insert (so a stale caller never re-airs), and rethrows any API failure.
  func airListenerQuestion(questionId: String, placeAfterSpinId: String) async throws {
    guard let jwt = auth.jwt else { throw CancellationError() }
    let expectedShowId = liveShowId
    let newSpins = try await api.insertListenerQuestionSpin(jwt, questionId, placeAfterSpinId)
    guard liveShowId == expectedShowId else { throw CancellationError() }
    withAnimation(.easeInOut(duration: 0.3)) {
      schedule = Schedule(
        stationId: stationId,
        spins: newSpins,
        dateProvider: DependencyDateProvider()
      )
      reorderedSpinIds = nil
      currentNowPlayingId = nowPlaying?.id
    }
  }

  func deleteSpin(_ spin: Spin) async {
    guard let jwt = auth.jwt else { return }

    let originalSchedule = schedule
    let originalReorderedIds = reorderedSpinIds

    // Mark spins after the deleted one as being rescheduled
    if let currentSpins = schedule?.current() {
      let affectedIds =
        currentSpins
        .filter { $0.airtime > spin.airtime }
        .map { $0.id }
      spinIdsBeingRescheduled = Set(affectedIds)
    }

    // Optimistically remove the spin
    if let currentSchedule = schedule {
      let filteredSpins = currentSchedule.current().filter { $0.id != spin.id }
      schedule = Schedule(
        stationId: stationId,
        spins: filteredSpins,
        dateProvider: DependencyDateProvider()
      )
      if reorderedSpinIds != nil {
        reorderedSpinIds = reorderedSpinIds?.filter { $0 != spin.id }
      }
    }

    let expectedShowId = liveShowId
    defer { spinIdsBeingRescheduled = [] }
    do {
      let newSpins = try await api.deleteSpin(jwt, spin.id)
      guard liveShowId == expectedShowId else { return }
      schedule = Schedule(
        stationId: stationId,
        spins: newSpins,
        dateProvider: DependencyDateProvider()
      )
      reorderedSpinIds = nil
      currentNowPlayingId = nowPlaying?.id
    } catch {
      guard liveShowId == expectedShowId else { return }
      schedule = originalSchedule
      reorderedSpinIds = originalReorderedIds
      presentedAlert = .schedulingError(error.localizedDescription)
    }
  }

  /// Handles moving spins in the list, automatically including grouped spins
  @discardableResult
  func moveSpins(from source: IndexSet, to destination: Int) async -> Bool {
    guard let jwt = auth.jwt else { return false }

    var spins = upcomingSpins

    // Get the indices being moved and check for contiguous grouped spins
    var indicesToMove = source
    for index in source where index < spins.count {
      indicesToMove.formUnion(Self.contiguousGroupIndices(around: index, in: spins))
    }

    // Sort indices to maintain relative order
    let sortedIndices = indicesToMove.sorted()

    // Extract the spins to move (in order)
    let spinsToMove = sortedIndices.map { spins[$0] }

    guard let spinToMove = spinsToMove.first else { return false }

    // Save original state for rollback
    let originalSchedule = schedule
    let originalReorderedIds = reorderedSpinIds

    let originalSpinIds = spins.map(\.id)

    // Remove from original positions (in reverse to maintain indices)
    for index in sortedIndices.reversed() {
      spins.remove(at: index)
    }

    // Calculate adjusted destination
    let adjustedDestination = min(
      destination - sortedIndices.filter { $0 < destination }.count,
      spins.count
    )

    // Insert at destination
    let insertionIndex = max(0, adjustedDestination)
    spins.insert(contentsOf: spinsToMove, at: insertionIndex)
    let firstChangedIndex =
      spins.indices.first { spins[$0].id != originalSpinIds[$0] } ?? spins.count
    spinIdsBeingRescheduled = Set(spins.dropFirst(firstChangedIndex).map(\.id))

    let placeAfterSpinId = insertionIndex > 0 ? spins[insertionIndex - 1].id : spinBeforeShowQueueId

    // Optimistically store the new order
    reorderedSpinIds = spins.map { $0.id }

    defer { spinIdsBeingRescheduled = [] }
    let expectedShowId = liveShowId
    do {
      let newSpins = try await api.moveSpin(jwt, spinToMove.id, placeAfterSpinId)
      guard liveShowId == expectedShowId else { return false }
      schedule = Schedule(
        stationId: stationId,
        spins: newSpins,
        dateProvider: DependencyDateProvider()
      )
      reorderedSpinIds = nil
      currentNowPlayingId = nowPlaying?.id
      return true
    } catch {
      guard liveShowId == expectedShowId else { return false }
      schedule = originalSchedule
      reorderedSpinIds = originalReorderedIds
      presentedAlert = .schedulingError(error.localizedDescription)
      return false
    }
  }

  /// Returns the indices of spins adjacent to `index` sharing its spinGroupId, matching
  /// the contiguous-run grouping `spinRows` uses.
  private static func contiguousGroupIndices(around index: Int, in spins: [Spin]) -> IndexSet {
    guard let groupId = spins[index].spinGroupId else { return [] }
    var indices = IndexSet()
    var before = index - 1
    while before >= 0, spins[before].spinGroupId == groupId {
      indices.insert(before)
      before -= 1
    }
    var after = index + 1
    while after < spins.count, spins[after].spinGroupId == groupId {
      indices.insert(after)
      after += 1
    }
    return indices
  }

  /// Handles a row-level reorder, moving every spin in a tied group together
  func moveSpinRows(from source: IndexSet, to destination: Int) async {
    let rows = spinRows
    guard !source.isEmpty, source.allSatisfy({ rows.indices.contains($0) }),
      destination >= 0, destination <= rows.count
    else { return }

    var reordered = rows
    reordered.move(fromOffsets: source, toOffset: destination)

    let movingIds = Set(source.flatMap { rows[$0].spins.map(\.id) })
    guard
      let firstMoved = reordered.firstIndex(where: { row in
        row.spins.contains { movingIds.contains($0.id) }
      })
    else { return }

    let saved = upcomingSpins
    let indices = IndexSet(saved.indices.filter { movingIds.contains(saved[$0].id) })
    let next = reordered.dropFirst(firstMoved).flatMap(\.spins)
      .first { !movingIds.contains($0.id) }
    let target = next.flatMap { next in saved.firstIndex { $0.id == next.id } } ?? saved.count

    await moveSpins(from: indices, to: target)
  }

  /// Deletes every spin in a tied group. The delete endpoint removes one spin at
  /// a time, so the whole group is hidden up front and then removed last-first,
  /// keeping members from reappearing between the sequential server responses.
  func deleteSpinRow(_ row: SpinRow) async {
    let members = row.spins.reversed().compactMap { member -> Spin? in
      guard let latest = schedule?.current().first(where: { $0.id == member.id }),
        canDeleteSpin(latest)
      else { return nil }
      return latest
    }
    guard !members.isEmpty else { return }

    let memberIds = members.map(\.id)
    spinIdsBeingDeleted.formUnion(memberIds)
    defer { spinIdsBeingDeleted.subtract(memberIds) }

    for member in members {
      await deleteSpin(member)
      if schedule?.current().contains(where: { $0.id == member.id }) == true { break }
    }
  }
}

struct SpinRow: Identifiable {
  let spins: [Spin]
  var id: String { spins.map(\.id).joined(separator: "|") }
  var dropAnchorSpinId: String? { spins.first?.id }
}

extension PlayolaAlert {
  static var errorLoadingSchedule: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load the station schedule. Please try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func schedulingError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func errorInsertingSpin(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }

  static var cannotInsertBeforeFirstSpin: PlayolaAlert {
    PlayolaAlert(
      title: "Cannot Place Here",
      message: "Voice tracks cannot be placed before the first song in the schedule.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func voicetrackUploadFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Upload Failed",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func notificationSendFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
