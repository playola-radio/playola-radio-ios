import Dependencies
import Foundation
import IdentifiedCollections

extension AskMeAnythingLivePageModel {
  func persistOpeningDraft() {
    guard !isShowActive, let userId = openingDraftUserId, !userId.isEmpty,
      auth.currentUser?.id == userId
    else { return }
    let items = IdentifiedArray(
      uniqueElements: openingItems.map { item in
        guard case .voicetrack(var recording, _) = item.content, !item.isReady else { return item }
        recording.status = .converting
        recording.audioBlockId = nil
        recording.convertedURL = nil
        return AMAOpeningItem(
          id: item.id, content: .voicetrack(recording, completedDurationMS: nil))
      })
    guard amaOpeningDrafts[userId]?[stationId] != items else { return }
    $amaOpeningDrafts.withLock {
      $0[userId, default: [:]][stationId] = items.isEmpty ? nil : items
    }
    let drafts = $amaOpeningDrafts
    Task { try? await drafts.save() }
  }

  func restoreOpeningDraft() {
    guard let userId = openingDraftUserId, !userId.isEmpty,
      let items = amaOpeningDrafts[userId]?[stationId]
    else { return }
    @Dependency(AMARecordingFiles.self) var recordingFiles
    openingItems = IdentifiedArray(
      uniqueElements: items.map { item in
        guard case .voicetrack(let recording, _) = item.content, !item.isReady else { return item }
        return AMAOpeningItem(
          id: item.id,
          content: .voicetrack(
            LocalVoicetrack(
              id: recording.id, originalURL: recordingFiles.restore(recording.originalURL),
              createdAt: recording.createdAt, title: recording.title), completedDurationMS: nil))
      })
  }

  func clearOpeningDraft() {
    guard let userId = openingDraftUserId else { return }
    $amaOpeningDrafts.withLock { $0[userId]?[stationId] = nil }
    let drafts = $amaOpeningDrafts
    Task { try? await drafts.save() }
    for item in openingItems where !item.isReady {
      guard case .voicetrack(let recording, _) = item.content else { continue }
      Task { await audioRecorder.deleteRecording(recording.originalURL) }
    }
  }

  func resumeOpeningUploads() {
    guard !isShowActive, auth.currentUser?.id == openingDraftUserId, let jwt = auth.jwt else {
      return
    }
    for item in openingItems where !item.isReady && uploadTasks[item.id] == nil {
      guard case .voicetrack(let recording, _) = item.content else { continue }
      uploadTasks[item.id] = Task { [weak self] in
        await self?.runVoicetrackUpload(
          itemId: item.id, voicetrack: recording, jwt: jwt, showId: nil)
      }
    }
  }
}

struct AMARecordingFiles: Sendable, DependencyKey {
  var preserve: @Sendable (URL, UUID) throws -> URL
  var restore: @Sendable (URL) -> URL

  static var liveValue: Self {
    let directory = URL.applicationSupportDirectory.appending(component: "ama-recordings")
    return Self(
      preserve: { source, id in
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(component: id.uuidString)
          .appendingPathExtension(source.pathExtension.isEmpty ? "wav" : source.pathExtension)
        try FileManager.default.moveItem(at: source, to: destination)
        return destination
      },
      restore: { directory.appending(component: $0.lastPathComponent) })
  }

  static var testValue: Self {
    Self(preserve: { source, _ in source }, restore: { $0 })
  }
}
