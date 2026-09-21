import Dependencies
import PlayolaPlayer
import SwiftUI

struct AMAQueuedRowData: Identifiable, StagingItem {
  let item: any StagingItem
  let isScheduling: Bool
  let schedulingFailed: Bool
  let awaitingConfirmation: Bool
  let canDiscard: Bool
  let canMove: Bool

  var id: String { item.stagingId }
  var stagingId: String { id }
  var titleText: String { item.titleText }
  var subtitleText: String {
    if isScheduling { return "Scheduling…" }
    if schedulingFailed { return "Scheduling failed" }
    if awaitingConfirmation { return "Show ending · Refresh to confirm" }
    return item.subtitleText
  }
  var subtitleColor: Color {
    if schedulingFailed { return .playolaRed }
    if isScheduling { return .playolaGray }
    return item.subtitleColor
  }
  var albumImageUrl: URL? { item.albumImageUrl }
  var icon: String? { item.icon }
  var audioBlockId: String? { item.audioBlockId }
  var isReady: Bool { item.isReady && !schedulingFailed }
  var isProcessing: Bool { item.isProcessing || isScheduling }
  var retryTitles: [String] {
    if awaitingConfirmation { return ["Refresh show"] }
    return schedulingFailed ? ["Retry scheduling"] : []
  }
}

extension AskMeAnythingLivePageModel {
  var pendingRows: [AMAQueuedRowData] {
    broadcast.stagingItems.map { item in
      let acceptedOutro = item.stagingId == outroStagingId && endingSpinId != nil
      return AMAQueuedRowData(
        item: item, isScheduling: schedulingItemId == item.stagingId,
        schedulingFailed: failedSchedulingItemIds.contains(item.stagingId),
        awaitingConfirmation: acceptedOutro,
        canDiscard: schedulingItemId != item.stagingId && !acceptedOutro,
        canMove: canEditLiveQueue && item.stagingId != outroStagingId)
    }
  }

  func enqueueSong(_ audioBlock: AudioBlock) {
    guard !broadcast.stagingItems.contains(where: { $0.stagingId == audioBlock.id }) else { return }
    rememberPendingPosition(audioBlock.stagingId)
    broadcast.stagingItems.append(audioBlock)
  }

  func retryPendingRow(_ id: String) async {
    guard broadcast.stagingItems.contains(where: { $0.stagingId == id }) else { return }
    if id == outroStagingId, endingSpinId != nil {
      await viewAppeared()
    } else if failedSchedulingItemIds.contains(id), !isScheduleProcessing {
      failedSchedulingItemIds.remove(id)
      await schedulePendingAudio()
    }
  }

  func discardPendingRow(_ id: String) async {
    guard pendingRows.first(where: { $0.id == id })?.canDiscard == true else { return }
    if let uuid = UUID(uuidString: id) { uploadTasks[uuid]?.cancel() }
    broadcast.stagingItems.removeAll { $0.stagingId == id }
    failedSchedulingItemIds.remove(id)
    pendingPredecessors[id] = nil
    if outroStagingId == id { outroStagingId = nil }
    await schedulePendingAudio()
  }

  func retryAddingAudio() async {
    guard !isAddingToShow, !isEndingShow else { return }
    failedSchedulingItemIds.removeAll()
    await schedulePendingAudio()
  }

  func schedulePendingAudio(for expectedShowId: String? = nil) async {
    guard let showId = broadcast.liveShowId,
      expectedShowId == nil || expectedShowId == showId,
      !isAddingToShow, !isEditingSchedule, !isEndingShow, !broadcast.isLoading,
      !isCheckingSchedule, !isAwaitingStartedSchedule, effectiveEndsAt == nil,
      auth.jwt != nil, !Task.isCancelled
    else { return }
    isAddingToShow = true
    defer {
      isAddingToShow = false
      schedulingItemId = nil
    }
    while let item = broadcast.stagingItems.first(where: {
      $0.isReady && !failedSchedulingItemIds.contains($0.stagingId)
        && ($0.stagingId != outroStagingId || broadcast.stagingItems.count == 1)
    }) {
      guard broadcast.liveShowId == showId, !Task.isCancelled else { return }
      schedulingItemId = item.stagingId
      if item.stagingId == outroStagingId {
        await submitQueuedOutro(item, showId: showId)
        return
      }
      guard let target = insertionTarget(for: item.stagingId) else {
        failedSchedulingItemIds.insert(item.stagingId)
        presentedAlert = PlayolaAlert(
          title: "Unable to Add Audio",
          message: "Refresh the show and try again. Your audio is ready to retry.",
          dismissButton: .cancel(Text("OK")))
        continue
      }
      let previousSpinIds = Set(broadcast.schedule?.spins.map(\.id) ?? [])
      await broadcast.insertStagingItem(stagingId: item.stagingId, beforeSpinId: target)
      guard broadcast.liveShowId == showId else { return }
      guard !broadcast.stagingItems.contains(where: { $0.stagingId == item.stagingId }) else {
        failedSchedulingItemIds.insert(item.stagingId)
        continue
      }
      replacePendingPosition(item, previousSpinIds: previousSpinIds)
      schedulePlaybackChanged()
    }
  }

  func acceptVoicetrack(url: URL, isOutro: Bool = false) throws {
    guard let jwt = auth.jwt else { throw RecordPromptError.notAuthenticated }
    let showId = broadcast.liveShowId
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    @Dependency(AMARecordingFiles.self) var recordingFiles
    let recordingId = uuid()
    let source = showId == nil ? try recordingFiles.preserve(url, recordingId) : url
    let voicetrack = LocalVoicetrack(
      id: recordingId, originalURL: source, createdAt: now,
      title: isOutro ? "Show Outro" : "Voicetrack \(formatter.string(from: now).lowercased())")
    let itemId: UUID
    if showId != nil {
      itemId = voicetrack.id
      rememberPendingPosition(voicetrack.stagingId)
      broadcast.stagingItems.append(voicetrack)
      if isOutro { outroStagingId = voicetrack.stagingId }
    } else {
      itemId = uuid()
      openingItems.append(
        AMAOpeningItem(id: itemId, content: .voicetrack(voicetrack, completedDurationMS: nil)))
    }
    uploadTasks[itemId] = Task { [weak self] in
      await self?.runVoicetrackUpload(
        itemId: itemId, voicetrack: voicetrack, jwt: jwt, showId: showId)
    }
  }

  func runVoicetrackUpload(
    itemId: UUID, voicetrack: LocalVoicetrack, jwt: String, showId: String?
  ) async {
    defer { uploadTasks[itemId] = nil }
    do {
      let audioBlock = try await voicetrackUploadService.processVoicetrack(
        voicetrack, stationId, jwt
      ) { [weak self] status in
        guard !Task.isCancelled else { return }
        self?.updateVoicetrack(itemId: itemId, showId: showId) {
          guard $0.audioBlockId == nil else { return }
          $0.status = status
        }
      }
      guard !Task.isCancelled, broadcast.liveShowId == showId else {
        if showId != nil { await audioRecorder.deleteRecording(voicetrack.originalURL) }
        return
      }
      updateVoicetrack(itemId: itemId, showId: showId) {
        $0.status = .completed
        $0.audioBlockId = audioBlock.id
      }
      if let showId {
        await schedulePendingAudio(for: showId)
      } else {
        openingItems[id: itemId]?.content.modify(\.voicetrack) { $0.1 = audioBlock.durationMS }
        do { try await $amaOpeningDrafts.save() } catch { return }
      }
      await audioRecorder.deleteRecording(voicetrack.originalURL)
    } catch {
      if showId == nil, Task.isCancelled { return }
      await audioRecorder.deleteRecording(voicetrack.originalURL)
      guard !Task.isCancelled, broadcast.liveShowId == showId else { return }
      if showId != nil {
        updateVoicetrack(itemId: itemId, showId: showId) {
          $0.status = .failed(error: "Upload failed — delete and record again")
        }
      } else {
        openingItems.remove(id: itemId)
      }
      presentedAlert = .voicetrackUploadFailed(error.localizedDescription)
    }
  }

  private func updateVoicetrack(
    itemId: UUID, showId: String?, update: (inout LocalVoicetrack) -> Void
  ) {
    guard broadcast.liveShowId == showId, uploadTasks[itemId]?.isCancelled == false else { return }
    if showId != nil {
      guard
        let index = broadcast.stagingItems.firstIndex(where: { $0.stagingId == itemId.uuidString }),
        var voicetrack = broadcast.stagingItems[index] as? LocalVoicetrack
      else { return }
      update(&voicetrack)
      broadcast.stagingItems[index] = voicetrack
    } else {
      openingItems[id: itemId]?.content.modify(\.voicetrack) { update(&$0.0) }
    }
  }

  private func submitQueuedOutro(_ item: any StagingItem, showId: String) async {
    guard let jwt = auth.jwt, let audioBlockId = item.audioBlockId else { return }
    isEndingShow = true
    defer { isEndingShow = false }
    do {
      let response = try await api.endLiveShow(jwt, stationId, showId, audioBlockId)
      guard broadcast.liveShowId == showId else { return }
      effectiveEndsAt = response.effectiveEndsAt
      endingSpinId = response.endingSpinId
      await broadcast.loadSchedule()
      updateLivePresentation()
    } catch {
      guard broadcast.liveShowId == showId else { return }
      failedSchedulingItemIds.insert(item.stagingId)
      let message: String
      switch error {
      case APIError.liveShowReplaced:
        message = "Another show has replaced this one. Return to Shows to open it."
      case APIError.liveShowFinished:
        message =
          "The show may have finished, or there is no safe place for the outro yet. Please try again."
      default:
        message = error.localizedDescription
      }
      presentedAlert = PlayolaAlert(
        title: "Unable to End Show", message: message, dismissButton: .cancel(Text("OK")))
    }
  }

  func cancelUploads() {
    for task in uploadTasks.values { task.cancel() }
  }
}
