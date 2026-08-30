//
//  BreakerCategoryDetailPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct BreakerCategoryDetailPageTests {

  private func makePlayingAudioPlayer(duration: TimeInterval = 18) -> AudioPlayerClient {
    AudioPlayerClient(
      loadFile: { _ in },
      play: {},
      pause: {},
      stop: {},
      seek: { _ in },
      currentTime: { 0 },
      duration: { duration },
      isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(
          PlaybackState(currentTime: 0, duration: duration, isPlaying: true))
        return PlaybackSession(
          play: {},
          pause: {},
          stop: {},
          seek: { _ in },
          cancel: {}
        )
      }
    )
  }

  private func makeSeekRecordingPlayer(
    seekedTo: LockIsolated<[TimeInterval]>, duration: TimeInterval = 18
  ) -> AudioPlayerClient {
    AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { duration }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: duration, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {}, stop: {},
          seek: { target in seekedTo.withValue { $0.append(target) } }, cancel: {})
      }
    )
  }

  @Test func navigationTitleIsCategoryName() {
    let model = BreakerCategoryDetailPageModel(category: .mockWith(name: "Fan Spotlights"))

    expectNoDifference(model.navigationTitle, "Fan Spotlights")
  }

  @Test func clipsMapFromCategoryAudioBlocks() {
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(id: "1", title: "Friday Night Roll Call", artist: "Maya R.")
      ]
    )
    let model = BreakerCategoryDetailPageModel(category: category)
    let block = model.clips[0]

    expectNoDifference(model.clipTitle(for: block), "Friday Night Roll Call")
    expectNoDifference(model.clipSubtitle(for: block), "Maya R.")
  }

  @Test func durationTextFormatsDurationMS() {
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(id: "1", durationMS: 18_000),
        .mockWith(id: "2", durationMS: 84_000),
      ]
    )
    let model = BreakerCategoryDetailPageModel(category: category)

    expectNoDifference(model.durationText(for: model.clips[0]), "0:18")
    expectNoDifference(model.durationText(for: model.clips[1]), "1:24")
  }

  @Test func inactiveClipShowsRestState() {
    let category = StationCategory.mockWith(
      audioBlocks: [.mockWith(id: "1", durationMS: 18_000)]
    )
    let model = BreakerCategoryDetailPageModel(category: category)
    let block = model.clips[0]

    expectNoDifference(model.progress(for: block), 0)
    expectNoDifference(model.elapsedText(for: block), "0:00")
    #expect(!model.isActive(block))
    #expect(!model.isPlaying(block))
    expectNoDifference(model.playButtonIcon(for: block), "play.fill")
  }

  @Test func playButtonTappedActivatesClip() async {
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )

    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.playButtonTapped(block)

    #expect(model.isActive(block))
    #expect(model.isPlaying(block))
    expectNoDifference(model.playButtonIcon(for: block), "stop.fill")
  }

  @Test func tappingActiveClipStopsPlayback() async {
    let sessionStopped = LockIsolated(false)
    let stoppingPlayer = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {},
          stop: { sessionStopped.setValue(true) },
          seek: { _ in }, cancel: {})
      }
    )

    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = stoppingPlayer
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))

    await model.playButtonTapped(block)

    #expect(!model.isActive(block))
    #expect(!model.isPlaying(block))
    #expect(sessionStopped.value)
  }

  @Test func tappingAgainWhileStartPendingCancelsAndStaysInactive() async {
    let lateSessionStopped = LockIsolated(false)
    let gate = LockIsolated<[CheckedContinuation<Void, Never>]>([])

    let gatedPlayer = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, _ in
        await withCheckedContinuation { continuation in
          gate.withValue { $0.append(continuation) }
        }
        return PlaybackSession(
          play: {}, pause: {},
          stop: { lateSessionStopped.setValue(true) },
          seek: { _ in }, cancel: {})
      }
    )

    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = gatedPlayer
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    async let firstTap: Void = model.playButtonTapped(block)
    while gate.count < 1 { await Task.yield() }

    await model.playButtonTapped(block)
    gate.withValue { $0[0].resume() }
    await firstTap

    #expect(!model.isActive(block))
    #expect(lateSessionStopped.value)
  }

  private func makeTrackingPlayer(
    gatedStopId: String,
    stopGate: LockIsolated<[CheckedContinuation<Void, Never>]>,
    started: LockIsolated<[String]>,
    stopped: LockIsolated<[String]>
  ) -> AudioPlayerClient {
    AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { url, onStateChange in
        let id = url.lastPathComponent
        started.withValue { $0.append(id) }
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {},
          stop: {
            if id == gatedStopId {
              await withCheckedContinuation { continuation in
                stopGate.withValue { $0.append(continuation) }
              }
            }
            stopped.withValue { $0.append(id) }
          },
          seek: { _ in }, cancel: {})
      }
    )
  }

  @Test func tappingTwiceWhileActiveStopIsPendingStartsOnlyNewestClip() async {
    let stopGate = LockIsolated<[CheckedContinuation<Void, Never>]>([])
    let started = LockIsolated<[String]>([])
    let stopped = LockIsolated<[String]>([])
    let player = makeTrackingPlayer(
      gatedStopId: "a.mp3", stopGate: stopGate, started: started, stopped: stopped)

    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(id: "a", downloadUrl: URL(string: "https://example.com/a.mp3")),
        .mockWith(id: "b", downloadUrl: URL(string: "https://example.com/b.mp3")),
        .mockWith(id: "c", downloadUrl: URL(string: "https://example.com/c.mp3")),
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let blockA = model.clips[0]
    let blockB = model.clips[1]
    let blockC = model.clips[2]

    await model.playButtonTapped(blockA)
    #expect(model.isActive(blockA))

    async let tapB: Void = model.playButtonTapped(blockB)
    while stopGate.count < 1 { await Task.yield() }

    await model.playButtonTapped(blockC)
    stopGate.withValue { $0[0].resume() }
    await tapB

    #expect(model.isActive(blockC))
    #expect(!model.isActive(blockA))
    #expect(!model.isActive(blockB))
    #expect(stopped.value.contains("a.mp3"))
    for id in started.value where id != "c.mp3" {
      #expect(stopped.value.contains(id))
    }
  }

  @Test func tappingCompletedClipReplaysInsteadOfConsumingTap() async {
    let started = LockIsolated<[String]>([])
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { url, onStateChange in
        started.withValue { $0.append(url.lastPathComponent) }
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )

    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.playButtonTapped(block)
    #expect(model.isPlaying(block))

    callbackBox.value?(PlaybackState(currentTime: 18, duration: 18, isPlaying: false))
    #expect(!model.isPlaying(block))

    await model.playButtonTapped(block)

    #expect(model.isPlaying(block))
    expectNoDifference(started.value, ["1.mp3", "1.mp3"])
  }

  @Test func tappingDifferentClipSwitchesActiveClip() async {
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3")),
        .mockWith(
          id: "2", durationMS: 24_000, downloadUrl: URL(string: "https://example.com/2.mp3")),
      ]
    )

    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 24)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let firstBlock = model.clips[0]
    let secondBlock = model.clips[1]

    await model.playButtonTapped(firstBlock)
    await model.playButtonTapped(secondBlock)

    #expect(!model.isActive(firstBlock))
    #expect(model.isActive(secondBlock))
  }

  @Test func scrubberAccessibilityLabelAndValueReflectClip() {
    let category = StationCategory.mockWith(
      audioBlocks: [.mockWith(id: "1", durationMS: 18_000)]
    )
    let model = BreakerCategoryDetailPageModel(category: category)
    let block = model.clips[0]

    expectNoDifference(
      model.scrubberAccessibilityLabel(for: block), "\(model.clipTitle(for: block)) scrubber")
    expectNoDifference(model.scrubberAccessibilityValue(for: block), "0:00 of 0:18")
  }

  @Test func scrubberAdjustedSeeksForwardWhenActive() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = makeSeekRecordingPlayer(seekedTo: seekedTo)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.playButtonTapped(block)
    await model.scrubberAdjusted(block, increment: true)

    expectNoDifference(seekedTo.value, [5])
  }

  @Test func scrubberAdjustedIsNoOpWhenInactive() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = makeSeekRecordingPlayer(seekedTo: seekedTo)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.scrubberAdjusted(block, increment: true)

    #expect(seekedTo.value.isEmpty)
  }

  @Test func viewDisappearedStopsPlayback() async {
    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )

    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    await model.playButtonTapped(block)
    await model.viewDisappeared()

    #expect(!model.isActive(block))
  }

  @Test func playButtonTappedWithNilDownloadUrlIsNoOp() async {
    let base = AudioBlock.mockWith(id: "1", durationMS: 18_000)
    let blockWithNoUrl = AudioBlock(
      id: base.id,
      title: base.title,
      artist: base.artist,
      durationMS: base.durationMS,
      endOfMessageMS: base.endOfMessageMS,
      beginningOfOutroMS: base.beginningOfOutroMS,
      endOfIntroMS: base.endOfIntroMS,
      lengthOfOutroMS: base.lengthOfOutroMS,
      downloadUrl: nil,
      s3Key: base.s3Key,
      s3BucketName: base.s3BucketName,
      type: base.type,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      album: base.album,
      popularity: base.popularity,
      youTubeId: base.youTubeId,
      isrc: base.isrc,
      spotifyId: base.spotifyId,
      imageUrl: base.imageUrl,
      transcription: base.transcription
    )
    let category = StationCategory.mockWith(audioBlocks: [blockWithNoUrl])

    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }

    await model.playButtonTapped(blockWithNoUrl)

    #expect(!model.isActive(blockWithNoUrl))
  }

  @Test func playButtonIsDisabledForClipWithoutDownloadUrl() {
    let base = AudioBlock.mockWith(id: "1")
    let blockWithNoUrl = AudioBlock(
      id: base.id, title: base.title, artist: base.artist, durationMS: base.durationMS,
      endOfMessageMS: base.endOfMessageMS, beginningOfOutroMS: base.beginningOfOutroMS,
      endOfIntroMS: base.endOfIntroMS, lengthOfOutroMS: base.lengthOfOutroMS,
      downloadUrl: nil, s3Key: base.s3Key, s3BucketName: base.s3BucketName, type: base.type,
      createdAt: base.createdAt, updatedAt: base.updatedAt, album: base.album,
      popularity: base.popularity, youTubeId: base.youTubeId, isrc: base.isrc,
      spotifyId: base.spotifyId, imageUrl: base.imageUrl, transcription: base.transcription)
    let playable = AudioBlock.mockWith(
      id: "2", downloadUrl: URL(string: "https://example.com/2.mp3"))
    let model = BreakerCategoryDetailPageModel(
      category: .mockWith(audioBlocks: [blockWithNoUrl, playable]))

    #expect(!model.isPlayButtonEnabled(for: model.clips[0]))
    #expect(model.isPlayButtonEnabled(for: model.clips[1]))
  }

  @Test func startResolvingAfterDisappearStopsItselfAndStaysInactive() async {
    let lateSessionStopped = LockIsolated(false)
    let gate = LockIsolated<[CheckedContinuation<Void, Never>]>([])

    let gatedPlayer = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, _ in
        await withCheckedContinuation { continuation in
          gate.withValue { $0.append(continuation) }
        }
        return PlaybackSession(
          play: {}, pause: {},
          stop: { lateSessionStopped.setValue(true) },
          seek: { _ in }, cancel: {})
      }
    )

    let category = StationCategory.mockWith(
      audioBlocks: [
        .mockWith(
          id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
      ]
    )
    let model = withDependencies {
      $0.audioPlayer = gatedPlayer
    } operation: {
      BreakerCategoryDetailPageModel(category: category)
    }
    let block = model.clips[0]

    async let tap: Void = model.playButtonTapped(block)
    while gate.count < 1 { await Task.yield() }

    await model.viewDisappeared()
    gate.withValue { $0[0].resume() }
    await tap

    #expect(!model.isActive(block))
    #expect(lateSessionStopped.value)
  }
}
