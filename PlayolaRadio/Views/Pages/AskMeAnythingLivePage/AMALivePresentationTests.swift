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
      await model.appendToShow(.mockWith(id: "new-song"), showId: "show")
      expectNoDifference(model.pendingAddIds, ["new-song"])
      #expect(model.presentedAlert != nil)
      await model.retryAddingAudio()
      expectNoDifference(model.pendingAddIds, [])
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
      #expect(model.pendingAddIds.isEmpty)
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
