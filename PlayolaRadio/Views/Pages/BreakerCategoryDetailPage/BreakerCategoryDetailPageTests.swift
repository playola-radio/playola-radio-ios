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
    expectNoDifference(model.playButtonIcon(for: block), "pause.fill")
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
