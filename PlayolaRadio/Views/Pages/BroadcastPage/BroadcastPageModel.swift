//
//  BroadcastPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import Combine
import Dependencies
import Foundation
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
  private let providedStationName: String?
  private var fetchedStationName: String?
  var schedule: Schedule?
  var isLoading: Bool = false
  var spinIdsBeingRescheduled: Set<String> = []
  var presentedAlert: PlayolaAlert?
  var currentNowPlayingId: String?
  private var reorderedSpinIds: [String]?  // nil means use default order
  var stagingItems: [any StagingItem] = []

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

  private var userName: String {
    auth.currentUser?.fullName ?? "Unknown"
  }

  init(stationId: String, stationName: String? = nil) {
    self.stationId = stationId
    self.providedStationName = stationName
    super.init()

    scheduleUpdateCancellable = NotificationCenter.default.publisher(
      for: .scheduleUpdated
    )
    .compactMap { notification -> String? in
      guard let id = notification.userInfo?["stationId"] as? String,
        id == stationId
      else { return nil }
      return notification.userInfo?["editorName"] as? String
    }
    .sink { [weak self] editorName in
      Task { [weak self] in
        await self?.refreshScheduleFromRemote(editorName: editorName)
      }
    }
  }

  func viewAppeared() async {
    await analytics.track(
      .viewedBroadcastScreen(
        stationId: stationId,
        stationName: navigationTitle,
        userName: userName
      ))
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadSchedule() }
      group.addTask { await self.loadStation() }
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
    let futureSpins = schedule.current().filter { $0.airtime > now }

    // If we have a custom order, use it
    if let orderedIds = reorderedSpinIds {
      let spinDict = Dictionary(uniqueKeysWithValues: futureSpins.map { ($0.id, $0) })
      // Return spins in the custom order, filtering out any that are no longer in futureSpins
      return orderedIds.compactMap { spinDict[$0] }
    }

    return futureSpins
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlaying else { return 0 }
    let elapsed = now.timeIntervalSince(spin.airtime)
    let duration = Double(spin.audioBlock.endOfMessageMS) / 1000.0
    guard duration > 0 else { return 0 }
    return min(max(elapsed / duration, 0), 1)
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
        stationName: navigationTitle,
        userName: userName
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
          stationName: navigationTitle,
          userName: userName
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

  func onAddSongTapped() {
    Task {
      await analytics.track(
        .broadcastSongSearchTapped(
          stationId: stationId,
          stationName: navigationTitle,
          userName: userName
        ))
    }
    let model = SongSearchPageModel(searchMode: .all)
    model.onDismiss = { [weak self] in
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    model.onSongSelected = { [weak self] audioBlock in
      self?.addSongToStaging(audioBlock)
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    songSearchPageModel = model
    mainContainerNavigationCoordinator.presentedSheet = .songSearchPage(model)
  }

  func addSongToStaging(_ audioBlock: AudioBlock) {
    guard !stagingItems.contains(where: { $0.stagingId == audioBlock.id }) else { return }
    stagingItems.append(audioBlock)
    Task {
      await analytics.track(
        .broadcastSongAdded(
          stationId: stationId,
          stationName: navigationTitle,
          userName: userName,
          songTitle: audioBlock.title,
          artistName: audioBlock.artist
        ))
    }
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
          userName: userName,
          messageLength: messageLength
        ))
      showNotifyListenersSheet = false
      notifyMessage = ""
    } catch {
      presentedAlert = .notificationSendFailed(error.localizedDescription)
    }
  }

  func insertStagingItem(stagingId: String, beforeSpinId: String) async {
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

    // Find the spin to place after (the one before beforeSpinId)
    guard let beforeIndex = upcomingSpins.firstIndex(where: { $0.id == beforeSpinId }) else {
      print("insertStagingItem: Target spin not found: \(beforeSpinId)")
      return
    }

    let placeAfterSpinId: String
    if beforeIndex == 0 {
      guard let nowPlayingId = nowPlaying?.id else {
        print("insertStagingItem: Cannot insert before first spin (no nowPlaying to place after)")
        presentedAlert = .cannotInsertBeforeFirstSpin
        return
      }
      placeAfterSpinId = nowPlayingId
    } else {
      placeAfterSpinId = upcomingSpins[beforeIndex - 1].id
    }

    do {
      let newSpins = try await api.insertSpin(jwt, audioBlockId, placeAfterSpinId)
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
      presentedAlert = .errorInsertingSpin(error.localizedDescription)
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

    do {
      let newSpins = try await api.deleteSpin(jwt, spin.id)
      schedule = Schedule(
        stationId: stationId,
        spins: newSpins,
        dateProvider: DependencyDateProvider()
      )
      reorderedSpinIds = nil
      currentNowPlayingId = nowPlaying?.id
    } catch {
      schedule = originalSchedule
      reorderedSpinIds = originalReorderedIds
      presentedAlert = .schedulingError(error.localizedDescription)
    }

    spinIdsBeingRescheduled = []
  }

  /// Handles moving spins in the list, automatically including grouped spins
  func moveSpins(from source: IndexSet, to destination: Int) async {
    guard let jwt = auth.jwt else { return }

    var spins = upcomingSpins

    // Get the indices being moved and check for grouped spins
    var indicesToMove = source
    for index in source {
      guard index < spins.count else { continue }
      let spin = spins[index]
      if let groupId = spin.spinGroupId {
        // Find all spins in the same group and add their indices
        for (idx, otherSpin) in spins.enumerated() where otherSpin.spinGroupId == groupId {
          indicesToMove.insert(idx)
        }
      }
    }

    // Sort indices to maintain relative order
    let sortedIndices = indicesToMove.sorted()

    // Extract the spins to move (in order)
    let spinsToMove = sortedIndices.map { spins[$0] }

    guard let spinToMove = spinsToMove.first else { return }

    // Save original state for rollback
    let originalSchedule = schedule
    let originalReorderedIds = reorderedSpinIds

    // Mark all spins as being rescheduled
    spinIdsBeingRescheduled = Set(spins.map { $0.id })

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

    // Determine placeAfterSpinId: the spin just before the insertion point, or nil if at beginning
    let placeAfterSpinId: String? = insertionIndex > 0 ? spins[insertionIndex - 1].id : nil

    // Optimistically store the new order
    reorderedSpinIds = spins.map { $0.id }

    do {
      let newSpins = try await api.moveSpin(jwt, spinToMove.id, placeAfterSpinId)
      schedule = Schedule(
        stationId: stationId,
        spins: newSpins,
        dateProvider: DependencyDateProvider()
      )
      reorderedSpinIds = nil
      currentNowPlayingId = nowPlaying?.id
    } catch {
      schedule = originalSchedule
      reorderedSpinIds = originalReorderedIds
      presentedAlert = .schedulingError(error.localizedDescription)
    }

    spinIdsBeingRescheduled = []
  }
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
