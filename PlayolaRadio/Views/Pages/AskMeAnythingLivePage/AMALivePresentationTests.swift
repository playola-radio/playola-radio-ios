import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMALivePresentationTests {
  // swiftlint:disable:next function_body_length
  @Test func laterSongSchedulesImmediatelyAndVoiceInsertsInItsReservedPlace() async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let uploading = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let inserted = LockIsolated<[String]>([])
    let response = LockIsolated<[Spin]>([])
    let ended = LockIsolated<[String]>([])
    let inserting = AsyncStream<Void>.makeStream()
    let releaseInsert = AsyncStream<Void>.makeStream()
    let date = Date(timeIntervalSince1970: 1_000_000)
    try await withDependencies {
      $0.date.now = date
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { recording, _, _, status in
        if recording.title == "Show Outro" { return .mockWith(id: "outro", type: "voiceTrack") }
        await status(.uploading(progress: 0.5))
        uploading.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return .mockWith(id: "uploaded", type: "voiceTrack")
      }
      $0.api.insertSpin = { _, audio, anchor in
        expectNoDifference(anchor, "voice")
        inserted.withValue { $0.append(audio) }
        if audio == "uploaded" {
          inserting.continuation.yield(())
          var iterator = releaseInsert.stream.makeAsyncIterator()
          await iterator.next()
        }
        response.withValue { spins in
          let index = spins.firstIndex { $0.id == anchor }! + 1
          let airtime = spins[index].airtime
          for offset in index..<spins.count { spins[offset] = spins[offset].withOffset(30) }
          spins.insert(
            .mockWith(
              id: "saved-" + audio,
              airtime: airtime,
              audioBlock: .mockWith(id: audio), liveShowId: "show"), at: index)
        }
        return response.value
      }
      $0.api.endLiveShow = { _, _, _, audio in
        expectNoDifference(inserted.value, ["later-song", "uploaded"])
        ended.withValue { $0.append(audio) }
        response.withValue {
          $0.append(
            .mockWith(
              id: "ending",
              airtime: date.addingTimeInterval(240), audioBlock: .mockWith(id: audio),
              liveShowId: "show"))
        }
        return .init(endingSpinId: "ending", effectiveEndsAt: date.addingTimeInterval(300))
      }
      $0.api.fetchSchedule = { _, _ in response.value }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder")
        return
      }
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/ordered.wav"), 30)
      var iterator = uploading.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.broadcast.stagingItems.first?.subtitleText, "Uploading 50%")
      model.enqueueSong(.mockWith(id: "later-song"))
      await model.schedulePendingAudio()
      expectNoDifference(model.broadcast.stagingItems.count, 1)
      expectNoDifference(inserted.value, ["later-song"])
      await model.endShowButtonTapped()
      guard case .recordWithMultiStepPromptPage(let outroRecorder) = coordinator.path.last else {
        Issue.record("Expected outro recorder")
        return
      }
      try outroRecorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/outro.wav"), 30)
      let outroId = try #require(model.outroStagingId.flatMap(UUID.init(uuidString:)))
      await model.uploadTasks[outroId]?.value
      expectNoDifference(
        model.pendingRows.map(\.subtitleText),
        ["Uploading 50%", "Ready"])
      expectNoDifference(ended.value, [])
      release.continuation.yield(())
      var insertIterator = inserting.stream.makeAsyncIterator()
      await insertIterator.next()
      expectNoDifference(model.pendingRows.first?.subtitleText, "Scheduling…")
      #expect(model.pendingRows.first?.isProcessing == true)
      #expect(model.pendingRows.first?.canDiscard == false)
      await model.retryAddingAudio()
      expectNoDifference(inserted.value, ["later-song", "uploaded"])
      releaseInsert.continuation.yield(())
      await model.waitForPendingUploads()
      expectNoDifference(inserted.value, ["later-song", "uploaded"])
      expectNoDifference(ended.value, ["outro"])
      #expect(model.broadcast.stagingItems.isEmpty)
    }
  }

  @Test(arguments: [false, true])
  // swiftlint:disable:next function_body_length
  func outroUsesDeferredAcceptanceAndAppearsInTheQueue(refreshFails: Bool) async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let uploading = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let ended = LockIsolated<[String]>([])
    let fetches = LockIsolated(0)
    let response = LockIsolated<[Spin]>([])
    let date = Date(timeIntervalSince1970: 1_000_000)
    try await withDependencies {
      $0.date.now = date
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, status in
        await status(.normalizing)
        uploading.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return .mockWith(id: "outro", type: "voiceTrack")
      }
      $0.api.endLiveShow = { _, _, show, audio in
        ended.withValue { $0.append(audio) }
        expectNoDifference(show, "show")
        return .init(endingSpinId: "ending", effectiveEndsAt: date.addingTimeInterval(300))
      }
      $0.api.fetchSchedule = { _, _ in
        fetches.withValue { $0 += 1 }
        if refreshFails && fetches.value == 1 { throw NSError(domain: "offline", code: 1) }
        return response.value
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let spins = model.broadcast.schedule!.spins
      response.setValue(
        spins + [
          .mockWith(
            id: "ending",
            airtime: date.addingTimeInterval(210), audioBlock: .mockWith(id: "outro"),
            liveShowId: "show")
        ])
      await model.endShowButtonTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected outro recorder")
        return
      }
      let accept = try #require(recorder.onRecordingAccepted)
      #expect(recorder.onUseRecording == nil)
      try accept(URL(fileURLWithPath: "/tmp/outro.wav"), 30)
      var iterator = uploading.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.broadcast.stagingItems.last?.titleText, "Show Outro")
      expectNoDifference(model.broadcast.stagingItems.last?.subtitleText, "Normalizing...")
      #expect(!model.canAddLiveAudio)
      #expect(!model.isEndShowEnabled)
      release.continuation.yield(())
      await model.waitForPendingUploads()
      if refreshFails {
        let row = try #require(model.pendingRows.last)
        expectNoDifference(row.subtitleText, "Show ending · Refresh to confirm")
        #expect(!row.canDiscard)
        await model.endShowButtonTapped()
        await model.retryPendingRow(row.id)
      }
      expectNoDifference(ended.value, ["outro"])
      #expect(model.broadcast.stagingItems.isEmpty)
      #expect(!model.isEndShowEnabled)
    }
  }

  @Test func failedUploadDoesNotBlockTheLaterSongAndCanBeDiscarded() async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let inserted = LockIsolated<[String]>([])
    let response = LockIsolated<[Spin]>([])
    try await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        throw NSError(domain: "offline", code: 1)
      }
      $0.api.insertSpin = { _, audio, _ in
        inserted.withValue { $0.append(audio) }
        return response.value
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      try model.acceptVoicetrack(url: URL(fileURLWithPath: "/tmp/failed.wav"))
      model.enqueueSong(.mockWith(id: "later-song"))
      await model.schedulePendingAudio()
      await model.waitForPendingUploads()
      expectNoDifference(inserted.value, ["later-song"])
      let failed = try #require(model.pendingRows.first)
      #expect(!failed.isProcessing)
      #expect(!failed.isReady)
      #expect(failed.canDiscard)
      expectNoDifference(failed.subtitleText, "Upload failed — delete and record again")
      await model.discardPendingRow(failed.id)
      expectNoDifference(inserted.value, ["later-song"])
      #expect(model.pendingRows.isEmpty)
    }
  }

  @Test func replacingShowIgnoresLateUploadCompletion() async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let inserted = LockIsolated<[String]>([])
    let date = Date(timeIntervalSince1970: 1_000_000)
    try await withDependencies {
      $0.date.now = date
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, status in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        await status(.finalizing)
        return .mockWith(id: "old-upload")
      }
      $0.api.insertSpin = { _, audio, _ in
        inserted.withValue { $0.append(audio) }
        return []
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      try model.acceptVoicetrack(url: URL(fileURLWithPath: "/tmp/old.wav"))
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(id: "replacement", airtime: date.addingTimeInterval(30), liveShowId: "new-show")
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      release.continuation.yield(())
      await model.waitForPendingUploads()
      expectNoDifference(model.broadcast.liveShowId, "new-show")
      expectNoDifference(inserted.value, [])
      #expect(model.pendingRows.isEmpty)
    }
  }

  @Test func replacingShowDoesNotApplyAnOldInsertionResponse() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return [
          .mockWith(id: "old-insert", airtime: date.addingTimeInterval(210), liveShowId: "show")
        ]
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      model.enqueueSong(.mockWith(id: "song"))
      let insertion = Task { await model.schedulePendingAudio() }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(id: "replacement", airtime: date.addingTimeInterval(30), liveShowId: "new-show")
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      release.continuation.yield(())
      await insertion.value
      expectNoDifference(model.broadcast.liveShowId, "new-show")
      expectNoDifference(model.broadcast.schedule?.spins.map(\.id), ["replacement"])
      #expect(model.pendingRows.isEmpty)
    }
  }

  @Test func replacingShowDoesNotApplyAnOldDeletionResponse() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.deleteSpin = { _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return [
          .mockWith(id: "stale-survivor", airtime: date.addingTimeInterval(210), liveShowId: "show")
        ]
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let toDelete = model.broadcast.schedule!.current().first { $0.id == "reserve" }!
      let deletion = Task { await model.broadcast.deleteSpin(toDelete) }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(id: "replacement", airtime: date.addingTimeInterval(30), liveShowId: "new-show")
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      release.continuation.yield(())
      await deletion.value
      expectNoDifference(model.broadcast.liveShowId, "new-show")
      expectNoDifference(model.broadcast.schedule?.spins.map(\.id), ["replacement"])
    }
  }

  @Test func replacingShowDoesNotRollBackAfterAStaleDeletionFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.deleteSpin = { _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        throw NSError(domain: "offline", code: 1)
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let toDelete = model.broadcast.schedule!.current().first { $0.id == "reserve" }!
      let deletion = Task { await model.broadcast.deleteSpin(toDelete) }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(id: "replacement", airtime: date.addingTimeInterval(30), liveShowId: "new-show")
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      release.continuation.yield(())
      await deletion.value
      expectNoDifference(model.broadcast.liveShowId, "new-show")
      expectNoDifference(model.broadcast.schedule?.spins.map(\.id), ["replacement"])
      #expect(model.presentedAlert == nil)
    }
  }

  @Test func acceptingOutroWhileAnEarlierInsertRunsKeepsItsPlace() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let response = LockIsolated<[Spin]>([])
    let ended = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in .mockWith(id: "outro") }
      $0.api.insertSpin = { _, _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return response.value
      }
      $0.api.endLiveShow = { _, _, _, audio in
        ended.withValue { $0.append(audio) }
        throw APIError.liveShowFinished
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      model.enqueueSong(.mockWith(id: "earlier-song"))
      await model.endShowButtonTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected outro recorder")
        return
      }
      let insert = Task { await model.schedulePendingAudio() }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      do { try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/outro.wav"), 30) } catch {
        Issue.record("Outro acceptance should queue behind the active insert: \(error)")
      }
      expectNoDifference(model.pendingRows.map(\.titleText).last, "Show Outro")
      await model.waitForPendingUploads()
      expectNoDifference(ended.value, [])
      release.continuation.yield(())
      await insert.value
      expectNoDifference(ended.value, ["outro"])
    }
  }

  @Test func startingImmediatelyShowsTheOpenerUntilSavedSpinsArrive() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let date = Date(timeIntervalSince1970: 1_000_000)
    let clock = LockIsolated(date)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    await withDependencies {
      $0.date = DateGenerator { clock.value }
      $0.api.startLiveShow = { _, _, _ in
        .init(
          liveShowId: "show", scheduledStartsAt: date.addingTimeInterval(138),
          scheduledEndsAt: date.addingTimeInterval(738))
      }
      $0.api.fetchSchedule = { _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return [
          .mockWith(
            id: "saved-intro", airtime: date.addingTimeInterval(138),
            audioBlock: .mockWith(id: "intro"), liveShowId: "show")
        ]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.openingItems = [
        AMAOpeningItem(id: UUID(), content: .intro(.mockWith(id: "intro", durationMS: 30_000))),
        AMAOpeningItem(
          id: UUID(), content: .song(.mockWith(title: "Hummingbird", durationMS: 570_000))),
      ]
      let start = Task { await model.startShowButtonTapped() }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.liveRows.map(\.title), ["Show Intro", "Hummingbird"])
      #expect(model.liveRows.allSatisfy { $0.spins.isEmpty && !$0.isEditable && $0.isProcessing })
      #expect(!model.canAddLiveAudio)
      expectNoDifference(model.waitingTitle, "Your Show Starts in 2:18")
      clock.withValue { $0 += 2 }
      model.playbackTick()
      expectNoDifference(model.waitingTitle, "Your Show Starts in 2:16")
      release.continuation.yield(())
      await start.value
      expectNoDifference(model.liveRows.map(\.id), ["saved-intro"])
      #expect(model.liveRows.allSatisfy { !$0.isProcessing })
      #expect(model.canAddLiveAudio)
    }
  }

  @Test(arguments: [false, true])
  func openerSurvivesAnUnconfirmedScheduleAndCanRetry(throwsError: Bool) async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let date = Date(timeIntervalSince1970: 1_000_000)
    let fetches = LockIsolated(0)
    await withDependencies {
      $0.date.now = date
      $0.api.startLiveShow = { _, _, _ in
        .init(
          liveShowId: "show", scheduledStartsAt: date.addingTimeInterval(138),
          scheduledEndsAt: date.addingTimeInterval(738))
      }
      $0.api.fetchSchedule = { _, _ in
        fetches.withValue { $0 += 1 }
        if fetches.value == 1 {
          if throwsError { throw NSError(domain: "offline", code: 1) }
          return []
        }
        return [.mockWith(id: "saved", airtime: date.addingTimeInterval(138), liveShowId: "show")]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.openingItems = [
        AMAOpeningItem(id: UUID(), content: .intro(.mockWith(durationMS: 600_000)))
      ]
      await model.startShowButtonTapped()
      model.schedulePlaybackChanged()
      expectNoDifference(model.liveRows.map(\.title), ["Show Intro"])
      #expect(model.isShowActive)
      #expect(model.scheduleRetryVisible)
      #expect(model.liveRows.allSatisfy { !$0.isProcessing && !$0.isEditable })
      await model.viewAppeared()
      expectNoDifference(model.liveRows.map(\.id), ["saved"])
      #expect(!model.scheduleRetryVisible)
    }
  }

  @Test func moveShowsOnlyAffectedSpinnersAndRestoresRowsAfterFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let inserted = LockIsolated<String?>(nil)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.insertSpin = { _, id, _ in
        inserted.setValue(id)
        return response.value
      }
      $0.api.moveSpin = { _, _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        throw NSError(domain: "offline", code: 1)
      }
    } operation: {
      let model = makeLiveModel(buffer: 392)
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let originalIds = model.liveRows.map(\.id)
      let move = Task { await model.moveLiveRows(from: IndexSet(integer: 1), to: 3) }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.liveRows.first?.airtimeOpacity, 1)
      #expect(model.liveRows.dropFirst().allSatisfy { $0.isProcessing })
      #expect(model.liveRows.allSatisfy { !$0.isEditable })
      #expect(!model.canAddLiveAudio)
      #expect(!model.isEndShowEnabled)
      model.enqueueSong(.mockWith(id: "finished-upload"))
      await model.schedulePendingAudio()
      expectNoDifference(inserted.value, nil)
      release.continuation.yield(())
      await move.value
      expectNoDifference(model.liveRows.map(\.id), originalIds)
      #expect(model.liveRows.allSatisfy { !$0.isProcessing })
      #expect(model.canAddLiveAudio)
      expectNoDifference(inserted.value, "finished-upload")
      #expect(model.pendingRows.map(\.id).isEmpty)
    }
  }

  @Test(arguments: [false, true])
  func insertingMarksTheAffectedSuffixAndAlwaysClearsProgress(throwsError: Bool) async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let clock = LockIsolated(Date(timeIntervalSince1970: 1_000_000))
    let response = LockIsolated<[Spin]>([])
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    await withDependencies {
      $0.date = DateGenerator { clock.value }
      $0.api.insertSpin = { _, _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        if throwsError { throw NSError(domain: "offline", code: 1) }
        return response.value
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      clock.withValue { $0 += 30 }
      model.playbackTick()
      let insert = Task {
        model.enqueueSong(.mockWith(id: "new"))
        await model.schedulePendingAudio()
      }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.broadcast.spinIdsBeingRescheduled, Set(["filler", "reserve"]))
      expectNoDifference(model.liveRows.filter(\.isProcessing).map(\.id), ["filler"])
      #expect(model.isScheduleProcessing)
      #expect(model.canAddLiveAudio)
      release.continuation.yield(())
      await insert.value
      #expect(model.broadcast.spinIdsBeingRescheduled.isEmpty)
      #expect(!model.isScheduleProcessing)
      expectNoDifference(model.pendingRows.map(\.id), throwsError ? ["new"] : [])
    }
  }

  @Test func deletingMarksOnlyDownstreamRowsAndClearsAfterRollback() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.deleteSpin = { _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        throw NSError(domain: "offline", code: 1)
      }
    } operation: {
      let model = makeLiveModel(buffer: 392)
      let deletion = Task { await model.deleteLiveRow(model.liveRows[1]) }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      expectNoDifference(model.liveRows.map(\.id), ["question", "song"])
      expectNoDifference(model.liveRows.filter(\.isProcessing).map(\.id), ["song"])
      release.continuation.yield(())
      await deletion.value
      expectNoDifference(model.liveRows.map(\.id), ["question", "voice", "song"])
      #expect(model.liveRows.allSatisfy { !$0.isProcessing })
      #expect(model.canAddLiveAudio)
    }
  }

  @Test func lowBufferRevealsOnlyTheNextFillerAndExpiresConfirmation() {
    let clock = LockIsolated(Date(timeIntervalSince1970: 1_000_000))
    withDependencies {
      $0.date = DateGenerator { clock.value }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(
            id: "content", airtime: clock.value.addingTimeInterval(-10),
            audioBlock: .mockWith(endOfMessageMS: 220_000), liveShowId: "show"),
          .mockWith(
            id: "filler", airtime: clock.value.addingTimeInterval(210),
            audioBlock: .mockWith(title: "Hummingbird", endOfMessageMS: 185_000),
            liveShowId: "show", isFiller: true),
          .mockWith(
            id: "reserve", airtime: clock.value.addingTimeInterval(395),
            liveShowId: "show", isFiller: true),
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      expectNoDifference(model.bufferLabel, "3:30 buffered")
      expectNoDifference(model.bufferPercentLabel, "35% of 10 min")
      expectNoDifference(model.bufferMessage, "Adding Hummingbird in 0:30")
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), [])
      clock.withValue { $0 += 30 }
      model.playbackTick()
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), ["filler"])
      expectNoDifference(model.bufferLabel, "6:05 buffered")
      expectNoDifference(model.bufferPercentLabel, "61% of 10 min")
      expectNoDifference(model.bufferMessage, "Hummingbird added to keep your show going")
      clock.withValue { $0 += 6 }
      model.playbackTick()
      expectNoDifference(model.bufferMessage, "")
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), ["filler"])
    }
  }

  @Test func waitingCountdownEndsAtTheScheduledStart() {
    let clock = LockIsolated(Date(timeIntervalSince1970: 1_000_000))
    withDependencies {
      $0.date = DateGenerator { clock.value }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(
            id: "rotation", airtime: clock.value.addingTimeInterval(-42),
            audioBlock: .mockWith(title: "My Boots", endOfMessageMS: 180_000)),
          .mockWith(
            id: "intro", airtime: clock.value.addingTimeInterval(138),
            audioBlock: .mockWith(endOfMessageMS: 30_000), liveShowId: "show"),
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      expectNoDifference(model.waitingTitle, "Your Show Starts in 2:18")
      #expect(model.isWaitingToAir)
      #expect(model.liveRows.first?.isEditable == false)
      clock.withValue { $0 += 138 }
      model.playbackTick()
      #expect(!model.isWaitingToAir)
      #expect(model.isShowActive)
    }
  }

  @Test func normalBufferAndQuestionPairPresentation() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let model = makeLiveModel(buffer: 392)
      expectNoDifference(model.bufferLabel, "6:32 buffered")
      expectNoDifference(model.bufferPercentLabel, "65% of 10 min")
      expectNoDifference(model.bufferMessage, "")
      expectNoDifference(
        model.liveRows.map(\.title),
        [
          "Question and Answer: Maya", "VoiceTrack", "Hummingbird",
        ])
      expectNoDifference(model.liveRows[0].subtitle, "1:24 · Question and answer")
      expectNoDifference(model.liveRows[0].spins.map(\.id), ["question", "answer"])
      #expect(!model.liveRows[0].isEditable)
      #expect(model.liveRows[1].isEditable)
    }
  }

  @Test func removingAQuestionPairDeletesAnswerThenQuestion() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let deleted = LockIsolated<[String]>([])
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.deleteSpin = { _, id in
        deleted.withValue { $0.append(id) }
        return Self.pairSpins(at: date).filter { !deleted.value.contains($0.id) }
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.broadcast.schedule = Schedule(
        stationId: "station", spins: Self.pairSpins(at: date),
        dateProvider: DependencyDateProvider())
      model.listenerQuestions = [.mockWith(audioBlockId: "q", answerAudioBlockId: "a")]
      model.schedulePlaybackChanged()
      model.scheduledStartsAt = date.addingTimeInterval(-1)
      await model.deleteLiveRow(model.liveRows[0])
      expectNoDifference(deleted.value, ["answer", "question"])
      expectNoDifference(model.liveRows.count, 0)
    }
  }

  @Test func failedQuestionDeleteAfterAnswerDeleteLeavesTheOrphanedQuestionRetryable() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let deleted = LockIsolated<[String]>([])
    let questionDeleteCalls = LockIsolated(0)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.deleteSpin = { _, id in
        if id == "question" {
          let attempt = questionDeleteCalls.withValue {
            $0 += 1
            return $0
          }
          if attempt == 1 { throw NSError(domain: "offline", code: 1) }
        }
        deleted.withValue { $0.append(id) }
        return Self.pairSpins(at: date).filter { !deleted.value.contains($0.id) }
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.broadcast.schedule = Schedule(
        stationId: "station", spins: Self.pairSpins(at: date),
        dateProvider: DependencyDateProvider())
      model.listenerQuestions = [.mockWith(audioBlockId: "q", answerAudioBlockId: "a")]
      model.schedulePlaybackChanged()
      model.scheduledStartsAt = date.addingTimeInterval(-1)

      await model.deleteLiveRow(model.liveRows[0])

      // The answer was actually deleted server-side before the question delete failed;
      // only the still-scheduled question remains, and it must stay retryable rather
      // than airing silently or getting stuck as an uneditable orphan.
      expectNoDifference(deleted.value, ["answer"])
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), ["question"])
      expectNoDifference(model.liveRows.map { $0.spins.map(\.id) }, [["question"]])
      #expect(model.liveRows[0].isEditable)
      #expect(model.presentedAlert != nil)

      await model.deleteLiveRow(model.liveRows[0])

      expectNoDifference(deleted.value, ["answer", "question"])
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), [])
      expectNoDifference(model.liveRows.count, 0)
    }
  }

  @Test func failedAppendKeepsAudioForRetryAtTheHiddenReserveBoundary() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let calls = LockIsolated(0)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { jwt, audio, anchor in
        expectNoDifference(jwt, "jwt")
        expectNoDifference(audio, "new-song")
        expectNoDifference(anchor, "voice")
        calls.withValue { $0 += 1 }
        if calls.value == 1 { throw NSError(domain: "offline", code: 1) }
        return [
          .mockWith(
            id: "inserted", airtime: date.addingTimeInterval(210),
            audioBlock: .mockWith(id: audio), liveShowId: "show")
        ]
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      model.enqueueSong(.mockWith(id: "new-song"))
      await model.schedulePendingAudio()
      expectNoDifference(model.pendingRows.map(\.id), ["new-song"])
      expectNoDifference(model.liveAddExplanation, "Added to the end of your playlist")
      expectNoDifference(model.pendingRows.first?.subtitleText, "Scheduling failed")
      expectNoDifference(model.pendingRows.first?.retryTitles, ["Retry scheduling"])
      #expect(model.presentedAlert != nil)
      await model.retryAddingAudio()
      expectNoDifference(model.pendingRows.map(\.id), [])
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), ["inserted"])
      expectNoDifference(calls.value, 2)
    }
  }

  @Test func revealedFillerStillUsesTheServerRemovableBoundary() {
    let clock = LockIsolated(Date(timeIntervalSince1970: 1_000_000))
    withDependencies {
      $0.date = DateGenerator { clock.value }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      clock.withValue { $0 += 30 }
      model.playbackTick()
      expectNoDifference(model.broadcast.upcomingSpins.last?.id, "filler")
      expectNoDifference(model.broadcast.showEndDropTargets, ["filler"])
      clock.withValue { $0 += 61 }
      model.playbackTick()
      expectNoDifference(model.broadcast.showEndDropTargets, ["reserve"])
    }
  }

  @Test func acceptedLiveVoicetrackUploadsAndAppendsToTheShow() async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let inserted = LockIsolated<[String]>([])
    let date = Date(timeIntervalSince1970: 1_000_000)
    try await withDependencies {
      $0.date.now = date
      $0.uuid = .incrementing
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        .mockWith(id: "uploaded", durationMS: 30_000)
      }
      $0.api.insertSpin = { _, audio, anchor in
        expectNoDifference(anchor, "voice")
        inserted.withValue { $0.append(audio) }
        return [
          .mockWith(
            id: "inserted", airtime: date.addingTimeInterval(210),
            audioBlock: .mockWith(id: audio), liveShowId: "show")
        ]
      }
    } operation: {
      let model = makeLiveModel(buffer: 210)
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected voicetrack recorder")
        return
      }
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/live-voice.wav"), 30)
      await model.waitForPendingUploads()
      expectNoDifference(inserted.value, ["uploaded"])
      #expect(model.openingItems.isEmpty)
      #expect(model.pendingRows.map(\.id).isEmpty)
    }
  }

  @Test func movingAGroupedRowMapsToItsUnderlyingSpins() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let moved = LockIsolated<[String]>([])
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.moveSpin = { _, id, anchor in
        moved.setValue([id, anchor ?? "nil"])
        return []
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      let tail = Spin.mockWith(
        id: "song", airtime: date.addingTimeInterval(300), liveShowId: "show")
      model.broadcast.schedule = Schedule(
        stationId: "station", spins: Self.pairSpins(at: date) + [tail],
        dateProvider: DependencyDateProvider())
      model.listenerQuestions = [.mockWith(audioBlockId: "q", answerAudioBlockId: "a")]
      model.schedulePlaybackChanged()
      model.scheduledStartsAt = date.addingTimeInterval(-1)
      await model.moveLiveRows(from: IndexSet(integer: 0), to: 2)
      expectNoDifference(moved.value, ["question", "song"])
    }
  }

  @Test func anUngroupedQuestionCannotConsumeOrDeleteUnrelatedSongs() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let date = Date(timeIntervalSince1970: 1_000_000)
    let question = Spin.mockWith(
      id: "question", airtime: date.addingTimeInterval(180),
      audioBlock: .mockWith(id: "q"), liveShowId: "show")
    let song = Spin.mockWith(id: "song", airtime: date.addingTimeInterval(300), liveShowId: "show")
    expectNoDifference(question.spinGroupId, nil)
    expectNoDifference(song.spinGroupId, nil)
    let deleted = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.deleteSpin = { _, id in
        deleted.withValue { $0.append(id) }
        return [song]
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      model.broadcast.schedule = Schedule(
        stationId: "station", spins: [question, song],
        dateProvider: DependencyDateProvider())
      model.listenerQuestions = [.mockWith(audioBlockId: "q")]
      model.schedulePlaybackChanged()
      model.scheduledStartsAt = date.addingTimeInterval(-1)
      expectNoDifference(model.liveRows.map { $0.spins.map(\.id) }, [["question"], ["song"]])
      await model.deleteLiveRow(model.liveRows[0])
      expectNoDifference(deleted.value, ["question"])
      expectNoDifference(model.broadcast.upcomingSpins.map(\.id), ["song"])
    }
  }

  @Test func listenerCountUsesPointInTimeEndpoint() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.getActiveListeningSessions = { jwt, station, airtime, end in
        expectNoDifference(jwt, "jwt")
        expectNoDifference(station, "station")
        expectNoDifference(airtime, date)
        expectNoDifference(end, nil)
        return .init(summary: .init(uniqueUsers: 38))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: "station")
      await model.loadLiveMetadata()
      expectNoDifference(model.listenerCountLabel, "38 listening")
    }
  }

  nonisolated private static func pairSpins(at date: Date) -> [Spin] {
    [
      .mockWith(
        id: "question", airtime: date.addingTimeInterval(180),
        audioBlock: .mockWith(id: "q", endOfMessageMS: 30_000),
        spinGroupId: "pair", liveShowId: "show"),
      .mockWith(
        id: "answer", airtime: date.addingTimeInterval(210),
        audioBlock: .mockWith(id: "a", endOfMessageMS: 54_000),
        spinGroupId: "pair", liveShowId: "show"),
    ]
  }

  private func makeLiveModel(buffer: TimeInterval) -> AskMeAnythingLivePageModel {
    let model = AskMeAnythingLivePageModel(stationId: "station")
    let date = model.now
    var spins: [Spin] = [
      .mockWith(
        id: "current", airtime: date.addingTimeInterval(-45),
        audioBlock: .mockWith(title: "My Boots", artist: "Kelsey Waldon", endOfMessageMS: 126_000),
        liveShowId: "show"),
      .mockWith(
        id: "question", airtime: date.addingTimeInterval(81),
        audioBlock: .mockWith(id: "q", endOfMessageMS: 30_000),
        spinGroupId: "pair", liveShowId: "show"),
      .mockWith(
        id: "answer", airtime: date.addingTimeInterval(111),
        audioBlock: .mockWith(id: "a", endOfMessageMS: 54_000),
        spinGroupId: "pair", liveShowId: "show"),
      .mockWith(
        id: "voice", airtime: date.addingTimeInterval(165),
        audioBlock: .mockWith(endOfMessageMS: 45_000, type: "voiceTrack"), liveShowId: "show"),
    ]
    if buffer > 210 {
      spins.append(
        .mockWith(
          id: "song", airtime: date.addingTimeInterval(210),
          audioBlock: .mockWith(
            title: "Hummingbird", artist: "Flatland Cavalry",
            endOfMessageMS: Int(buffer - 210) * 1000), liveShowId: "show"))
    }
    spins.append(
      .mockWith(
        id: "filler", airtime: date.addingTimeInterval(buffer),
        audioBlock: .mockWith(
          title: "Hummingbird", artist: "Flatland Cavalry", endOfMessageMS: 185_000),
        liveShowId: "show", isFiller: true))
    spins.append(
      .mockWith(
        id: "reserve", airtime: date.addingTimeInterval(buffer + 185),
        liveShowId: "show", isFiller: true))
    model.broadcast.schedule = Schedule(
      stationId: "station", spins: spins, dateProvider: DependencyDateProvider())
    model.listenerQuestions = [
      .mockWith(
        audioBlockId: "q", answerAudioBlockId: "a",
        listener: .mockWith(firstName: "Maya"))
    ]
    model.listenerCount = 38
    model.schedulePlaybackChanged()
    return model
  }
}
