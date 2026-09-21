import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
@_spi(Internals) import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMADraftTests {
  private let testStationId = "station-abc"

  private func introItem(durationMS: Int) -> AMAOpeningItem {
    AMAOpeningItem(id: UUID(), content: .intro(.mockWith(id: "intro", durationMS: durationMS)))
  }

  @Test func prefilledPlaylistSurvivesLeavingAndReopeningSetup() {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems = [
      introItem(durationMS: 30_000),
      AMAOpeningItem(id: UUID(), content: .song(.mockWith(id: "song", durationMS: 570_000))),
      AMAOpeningItem(
        id: UUID(),
        content: .voicetrack(
          LocalVoicetrack(
            originalURL: URL(fileURLWithPath: "/tmp/already-uploaded.wav"), status: .completed,
            title: "My recording", audioBlockId: "voice"), completedDurationMS: 12_000)),
    ]
    model.setupAbandoned()

    let restored = AskMeAnythingLivePageModel(stationId: testStationId)

    expectNoDifference(restored.openingItems, model.openingItems)
    #expect(restored.isStartShowEnabled)
    #expect(restored.hasRecordedIntro)
  }

  @Test func prefilledPlaylistBelongsToItsAccountAndStation() {
    let owner = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    @Shared(.auth) var auth = owner
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 600_000))
    #expect(AskMeAnythingLivePageModel(stationId: "other-station").openingItems.isEmpty)
    $auth.withLock {
      $0 = Auth(
        loggedInUser: LoggedInUser(id: "other", firstName: "Other", email: "other@example.com"))
    }
    #expect(AskMeAnythingLivePageModel(stationId: testStationId).openingItems.isEmpty)
    $auth.withLock { $0 = owner }
    expectNoDifference(
      AskMeAnythingLivePageModel(stationId: testStationId).openingItems, model.openingItems)
  }

  @Test func acceptedStartClearsDraftButKeepsProvisionalQueue() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let model = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.startLiveShow = { _, _, _ in
        StartLiveShowResponse(
          liveShowId: "show", scheduledStartsAt: .distantFuture, scheduledEndsAt: .distantFuture)
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))

    await model.startShowButtonTapped()

    expectNoDifference(model.openingItems.count, 1)
    #expect(model.isAwaitingStartedSchedule)
    #expect(AskMeAnythingLivePageModel(stationId: testStationId).openingItems.isEmpty)
  }

  @Test func rejectedStartKeepsDraft() async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let model = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.startLiveShow = { _, _, _ in throw APIError.liveShowUnavailable(delayUntil: nil) }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(introItem(durationMS: 600_000))

    await model.startShowButtonTapped()

    #expect(model.presentedAlert != nil)
    expectNoDifference(
      AskMeAnythingLivePageModel(stationId: testStationId).openingItems, model.openingItems)
  }
  @Test func interruptedSetupUploadResumesInPlaceAfterReopening() async throws {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let started = AsyncStream<Void>.makeStream()
    let suspended = AsyncStream<Void>.makeStream()
    let attempts = LockIsolated(0)
    let deleted = LockIsolated<[URL]>([])
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.fetchSchedule = { _, _ in [] }
      $0.audioRecorder.deleteRecording = { url in deleted.withValue { $0.append(url) } }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, status in
        let attempt = attempts.withValue {
          $0 += 1
          return $0
        }
        if attempt == 1 {
          await status(.uploading(progress: 0.5))
          started.continuation.yield(())
          for await _ in suspended.stream {}
          throw CancellationError()
        }
        return .mockWith(id: "uploaded", durationMS: 20_000)
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      model.openingItems.append(introItem(durationMS: 30_000))
      let source = URL(fileURLWithPath: "/tmp/interrupted.wav")
      try model.acceptVoicetrack(url: source)
      for await _ in started.stream { break }
      model.openingItems.append(
        AMAOpeningItem(id: UUID(), content: .song(.mockWith(id: "later-song"))))
      model.setupAbandoned()
      await model.waitForPendingUploads()
      #expect(deleted.value.isEmpty)

      let restored = AskMeAnythingLivePageModel(stationId: testStationId)
      await restored.viewAppeared()
      await restored.waitForPendingUploads()

      expectNoDifference(
        restored.openingItems.compactMap(\.audioBlockId), ["intro", "uploaded", "later-song"])
      expectNoDifference(restored.openingItems[1].readyDurationMS, 20_000)
      expectNoDifference(attempts.value, 2)
      expectNoDifference(deleted.value, [source])
    }
  }

  @Test func draftReloadsFromStorageWithoutTheOriginalSharedCache() async throws {
    let files = LockIsolated<[URL: Data]>([:])
    let owner = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let opener = introItem(durationMS: 600_000)
    try await withDependencies {
      $0 = DependencyValues()
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.defaultFileStorage = .inMemory(fileSystem: files)
    } operation: {
      @Shared(.auth) var auth = owner
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      model.openingItems.append(opener)
      try model.acceptVoicetrack(url: URL(fileURLWithPath: "/tmp/cold-start.wav"))
      await model.waitForPendingUploads()
      try await model.$amaOpeningDrafts.save()
    }
    withDependencies {
      $0 = DependencyValues()
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.defaultFileStorage = .inMemory(fileSystem: files)
    } operation: {
      @Shared(.auth) var auth = owner
      let restored = AskMeAnythingLivePageModel(stationId: testStationId)
      expectNoDifference(restored.openingItems.first, opener)
      expectNoDifference(restored.openingItems.count, 2)
      let allReady = restored.openingItems.allSatisfy(\.isReady)
      #expect(allReady)
    }
  }

  @Test func draftRecordingMovesToDurableStorageAndRebasesItsContainer() throws {
    let source = URL.temporaryDirectory.appending(component: UUID().uuidString + ".wav")
    let bytes = Data("recording".utf8)
    try bytes.write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let files = AMARecordingFiles.liveValue
    let durable = try files.preserve(source, UUID())
    defer { try? FileManager.default.removeItem(at: durable) }

    expectNoDifference(try Data(contentsOf: durable), bytes)
    #expect(!FileManager.default.fileExists(atPath: source.path))
    let oldContainerURL = URL(fileURLWithPath: "/old-container/ama-recordings")
      .appending(component: durable.lastPathComponent)
    expectNoDifference(files.restore(oldContainerURL), durable)
  }

  @Test(arguments: [false, true])
  func restoredUploadWaitsForScheduleAndIsDiscardedIfShowAlreadyStarted(showExists: Bool) async {
    @Shared(.auth) var auth = Auth(
      loggedInUser: LoggedInUser(id: "host", firstName: "Host", email: "host@example.com"))
    let attempts = LockIsolated(0)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { _, _ in
        guard showExists else { throw APIError.liveShowFinished }
        return [.mockWith(airtime: date.addingTimeInterval(300), liveShowId: "existing")]
      }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        attempts.withValue { $0 += 1 }
        return .mockWith()
      }
    } operation: {
      let setup = AskMeAnythingLivePageModel(stationId: testStationId)
      setup.openingItems.append(introItem(durationMS: 600_000))
      setup.openingItems.append(
        AMAOpeningItem(
          id: UUID(),
          content: .voicetrack(
            LocalVoicetrack(
              originalURL: URL(fileURLWithPath: "/tmp/pending.wav"), title: "Pending"),
            completedDurationMS: nil)))
      let restored = AskMeAnythingLivePageModel(stationId: testStationId)

      await restored.viewAppeared()
      await restored.waitForPendingUploads()

      expectNoDifference(attempts.value, 0)
      expectNoDifference(restored.isShowActive, showExists)
      expectNoDifference(
        AskMeAnythingLivePageModel(stationId: testStationId).openingItems.count, showExists ? 0 : 2)
    }
  }

}
