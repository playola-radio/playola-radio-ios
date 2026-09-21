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
struct AMAQueuePlacementTests {
  private let date = Date(timeIntervalSince1970: 1_000_000)

  @Test func songCanMoveAcrossUploadingVoiceWithoutARequestThenVoiceUsesItsNewPosition() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let anchors = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, audio, anchor in
        anchors.withValue { $0.append(anchor) }
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      model.enqueueSong(.mockWith(id: "song", title: "New Song"))
      await model.schedulePendingAudio()
      expectNoDifference(
        model.playlistRows.map(\.id),
        ["spin:a", "spin:b", "pending:" + voice.stagingId, "spin:placed-song"])
      await model.moveLiveRows(from: IndexSet(integer: 3), to: 2)
      expectNoDifference(
        model.playlistRows.map(\.id),
        ["spin:a", "spin:b", "spin:placed-song", "pending:" + voice.stagingId])
      completeVoice(voice, audio: "voice", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(anchors.value, ["b", "placed-song"])
      expectNoDifference(model.liveRows.map(\.id), ["a", "b", "placed-song", "placed-voice"])
    }
  }

  @Test func uploadingVoiceCanMoveLocallyBeforeAnExistingSong() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let anchors = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, audio, anchor in
        anchors.withValue { $0.append(anchor) }
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      await model.moveLiveRows(from: IndexSet(integer: 2), to: 0)
      expectNoDifference(model.playlistRows.first?.id, "pending:" + voice.stagingId)
      expectNoDifference(anchors.value, [])
      completeVoice(voice, audio: "voice", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(anchors.value, ["current"])
      expectNoDifference(model.liveRows.map(\.id), ["placed-voice", "a", "b"])
    }
  }

  @Test(arguments: [false, true])
  func movingASavedSongUpdatesPendingPlacementAndRollsBackOnFailure(fails: Bool) async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let anchors = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, audio, anchor in
        anchors.withValue { $0.append(anchor) }
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
      $0.api.moveSpin = { _, id, anchor in
        expectNoDifference(id, "b")
        expectNoDifference(anchor, "placed-song")
        if fails { throw APIError.liveShowFinished }
        return response.withValue { spins in
          let moved = spins.remove(at: spins.firstIndex { $0.id == id }!)
          let index = spins.firstIndex { $0.id == anchor }! + 1
          spins.insert(moved.withOffset(120), at: index)
          return spins
        }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      model.enqueueSong(.mockWith(id: "song"))
      await model.schedulePendingAudio()
      await model.moveLiveRows(from: IndexSet(integer: 1), to: 4)
      completeVoice(voice, audio: "voice", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(anchors.value, ["b", fails ? "b" : "a"])
    }
  }

  @Test func deletingThePredecessorKeepsVoiceAheadOfTheLaterSong() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let anchors = LockIsolated<[String]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, audio, anchor in
        anchors.withValue { $0.append(anchor) }
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
      $0.api.deleteSpin = { _, id in
        response.withValue {
          $0.removeAll { $0.id == id }
          return $0
        }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      model.enqueueSong(.mockWith(id: "song"))
      await model.schedulePendingAudio()
      await model.deleteLiveRow(model.liveRows[1])
      completeVoice(voice, audio: "voice", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(anchors.value, ["b", "a"])
      expectNoDifference(model.liveRows.map(\.id), ["a", "placed-voice", "placed-song"])
    }
  }

  @Test func aPositionInsideTheSafetyWindowMovesForwardBeforeInsertion() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let clock = LockIsolated(date)
    let response = LockIsolated<[Spin]>([])
    let anchors = LockIsolated<[String]>([])
    await withDependencies {
      $0.date = DateGenerator { clock.value }
      $0.api.insertSpin = { _, audio, anchor in
        anchors.withValue { $0.append(anchor) }
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      await model.moveLiveRows(from: IndexSet(integer: 2), to: 0)
      clock.withValue { $0 += 100 }
      model.playbackTick()
      expectNoDifference(
        model.playlistRows.prefix(2).map(\.id), ["spin:a", "pending:" + voice.stagingId])
      completeVoice(voice, audio: "voice", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(anchors.value, ["a"])
    }
  }

  @Test func reverseUploadCompletionPreservesTheIntendedOrder() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.insertSpin = { _, audio, anchor in
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let first = stageVoice(model)
      let second = stageVoice(model)
      completeVoice(second, audio: "second", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(
        model.playlistRows.suffix(2).map(\.id),
        ["pending:" + first.stagingId, "spin:placed-second"])
      completeVoice(first, audio: "first", model: model)
      await model.schedulePendingAudio()
      expectNoDifference(model.liveRows.map(\.id), ["a", "b", "placed-first", "placed-second"])
    }
  }

  @Test func failedRecordingInsertDoesNotBlockSongsAndRetriesAtItsPosition() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let response = LockIsolated<[Spin]>([])
    let calls = LockIsolated<[String]>([])
    let endings = LockIsolated(0)
    await withDependencies {
      $0.date.now = date
      $0.api.endLiveShow = { _, _, _, _ in
        endings.withValue { $0 += 1 }
        throw APIError.liveShowFinished
      }
      $0.api.insertSpin = { _, audio, anchor in
        calls.withValue { $0.append(audio) }
        if calls.value.count == 1 { throw APIError.liveShowFinished }
        expectNoDifference(anchor, "b")
        return response.withValue { Self.insert(audio, after: anchor, into: &$0) }
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      let voice = stageVoice(model)
      completeVoice(voice, audio: "voice", model: model)
      model.enqueueSong(.mockWith(id: "song"))
      await model.schedulePendingAudio()
      expectNoDifference(calls.value, ["voice", "song"])
      expectNoDifference(model.failedSchedulingItemIds, [voice.stagingId])
      let outro = stageVoice(model)
      completeVoice(outro, audio: "outro", model: model)
      model.outroStagingId = outro.stagingId
      await model.schedulePendingAudio()
      expectNoDifference(endings.value, 0)
      expectNoDifference(model.pendingRows.first?.retryTitles, ["Retry scheduling"])
      await model.retryPendingRow(voice.stagingId)
      expectNoDifference(endings.value, 1)
      expectNoDifference(calls.value, ["voice", "song", "voice"])
      expectNoDifference(model.liveRows.map(\.id), ["a", "b", "placed-voice", "placed-song"])
    }
  }

  @Test func replacingTheShowDuringAMoveClearsItsLocalPositions() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let response = LockIsolated<[Spin]>([])
    await withDependencies {
      $0.date.now = date
      $0.api.moveSpin = { _, _, _ in
        started.continuation.yield(())
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return response.value
      }
    } operation: {
      let model = makeModel()
      let spins = model.broadcast.schedule!.spins
      response.setValue(spins)
      _ = stageVoice(model)
      let move = Task { await model.moveLiveRows(from: IndexSet(integer: 0), to: 2) }
      var iterator = started.stream.makeAsyncIterator()
      await iterator.next()
      model.broadcast.schedule = Schedule(
        stationId: "station",
        spins: [
          .mockWith(id: "replacement", airtime: date.addingTimeInterval(30), liveShowId: "new-show")
        ], dateProvider: DependencyDateProvider())
      model.schedulePlaybackChanged()
      release.continuation.yield(())
      await move.value
      expectNoDifference(model.broadcast.liveShowId, "new-show")
      expectNoDifference(model.playlistRows.map(\.id), ["spin:replacement"])
      #expect(model.pendingPredecessors.isEmpty)
    }
  }

  private func makeModel() -> AskMeAnythingLivePageModel {
    let model = AskMeAnythingLivePageModel(stationId: "station")
    model.broadcast.schedule = Schedule(
      stationId: "station",
      spins: [
        .mockWith(
          id: "current", airtime: date.addingTimeInterval(-30),
          audioBlock: .mockWith(endOfMessageMS: 180_000), liveShowId: "show"),
        .mockWith(
          id: "a", airtime: date.addingTimeInterval(150),
          audioBlock: .mockWith(endOfMessageMS: 90_000), liveShowId: "show"),
        .mockWith(
          id: "b", airtime: date.addingTimeInterval(240),
          audioBlock: .mockWith(endOfMessageMS: 90_000), liveShowId: "show"),
        .mockWith(
          id: "filler", airtime: date.addingTimeInterval(330), liveShowId: "show", isFiller: true),
      ], dateProvider: DependencyDateProvider())
    model.schedulePlaybackChanged()
    return model
  }

  private func stageVoice(_ model: AskMeAnythingLivePageModel) -> LocalVoicetrack {
    let voice = LocalVoicetrack(originalURL: URL(fileURLWithPath: "/tmp/voice.wav"), title: "Voice")
    model.rememberPendingPosition(voice.stagingId)
    model.broadcast.stagingItems.append(voice)
    return voice
  }

  private func completeVoice(
    _ voice: LocalVoicetrack, audio: String, model: AskMeAnythingLivePageModel
  ) {
    var ready = voice
    ready.audioBlockId = audio
    ready.status = .completed
    let index = model.broadcast.stagingItems.firstIndex { $0.stagingId == voice.stagingId }!
    model.broadcast.stagingItems[index] = ready
  }

  nonisolated private static func insert(
    _ audio: String, after anchor: String, into spins: inout [Spin]
  ) -> [Spin] {
    let index = spins.firstIndex { $0.id == anchor }! + 1
    let airtime = spins[index - 1].endtime
    for offset in index..<spins.count { spins[offset] = spins[offset].withOffset(30) }
    spins.insert(
      .mockWith(
        id: "placed-" + audio, airtime: airtime,
        audioBlock: .mockWith(id: audio, endOfMessageMS: 30_000), liveShowId: "show"), at: index)
    return spins
  }
}
