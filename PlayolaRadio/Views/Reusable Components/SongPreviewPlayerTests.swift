//
//  SongPreviewPlayerTests.swift
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
struct SongPreviewPlayerTests {

  private func playingPlayer(duration: TimeInterval = 18) -> AudioPlayerClient {
    AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { duration }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: duration, isPlaying: true))
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )
  }

  private func block(_ id: String, durationMS: Int = 18_000) -> AudioBlock {
    .mockWith(id: id, durationMS: durationMS, downloadUrl: URL(string: "https://example.com/1.mp3"))
  }

  // .mockWith falls back to a default downloadUrl when passed nil, so reconstruct the block to
  // genuinely clear it (mirrors MusicCategoryDetailPageTests.blockWithoutDownloadUrl).
  private func blockWithoutDownloadUrl(_ base: AudioBlock) -> AudioBlock {
    AudioBlock(
      id: base.id, title: base.title, artist: base.artist, durationMS: base.durationMS,
      endOfMessageMS: base.endOfMessageMS, beginningOfOutroMS: base.beginningOfOutroMS,
      endOfIntroMS: base.endOfIntroMS, lengthOfOutroMS: base.lengthOfOutroMS,
      downloadUrl: nil, s3Key: base.s3Key, s3BucketName: base.s3BucketName, type: base.type,
      createdAt: base.createdAt, updatedAt: base.updatedAt, album: base.album,
      popularity: base.popularity, youTubeId: base.youTubeId, isrc: base.isrc,
      spotifyId: base.spotifyId, imageUrl: base.imageUrl, transcription: base.transcription)
  }

  @Test func toggleStartsPlayback() async {
    let player = withDependencies {
      $0.audioPlayer = playingPlayer()
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)

    #expect(player.isActive(song))
    #expect(player.isPlaying(song))
    expectNoDifference(player.playButtonIcon(for: song), "pause.fill")
  }

  @Test func togglingActiveSongStopsPlayback() async {
    let stopped = LockIsolated(false)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {}, stop: { stopped.setValue(true) }, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)
    await player.toggle(song)

    #expect(!player.isActive(song))
    #expect(stopped.value)
  }

  @Test func togglingDifferentSongSwitchesActiveSong() async {
    let player = withDependencies {
      $0.audioPlayer = playingPlayer(duration: 24)
    } operation: {
      SongPreviewPlayer()
    }
    let first = block("1")
    let second = block("2")

    await player.toggle(first)
    await player.toggle(second)

    #expect(!player.isActive(first))
    #expect(player.isActive(second))
  }

  @Test func didFinishResetsToIdle() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)
    #expect(player.isActive(song))

    callbackBox.value?(
      PlaybackState(currentTime: 18, duration: 18, isPlaying: false, didFinish: true))

    #expect(!player.isActive(song))
  }

  @Test func nearEndStallWithoutDidFinishDoesNotComplete() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 1, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)

    // A stall at 98% (progress >= 0.97) with no didFinish must NOT be treated as completion.
    callbackBox.value?(PlaybackState(currentTime: 17.7, duration: 18, isPlaying: false))

    #expect(player.isActive(song))
    #expect(player.isBuffering(song))
  }

  @Test func nonFiniteDurationDoesNotTrapDurationText() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { .infinity }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: .infinity, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)
    callbackBox.value?(PlaybackState(currentTime: 0, duration: .infinity, isPlaying: true))

    expectNoDifference(player.durationText(for: song), "0:00")
  }

  @Test func staleCallbackFromPreviousSongIsIgnored() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let first = block("1")
    let second = block("2")

    await player.toggle(first)
    let staleCallback = callbackBox.value
    await player.toggle(second)

    // A didFinish arriving from the first (torn-down) session must not reset the current song.
    staleCallback?(PlaybackState(currentTime: 18, duration: 18, isPlaying: false, didFinish: true))

    #expect(player.isActive(second))
  }

  @Test func stopTearsDownSession() async {
    let stopped = LockIsolated(false)
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 18, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {}, stop: { stopped.setValue(true) }, seek: { _ in }, cancel: {})
      }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    let song = block("1")

    await player.toggle(song)
    await player.stop()

    #expect(!player.isActive(song))
    #expect(stopped.value)
  }

  @Test func toggleWithNilDownloadUrlIsNoOp() async {
    let player = withDependencies {
      $0.audioPlayer = playingPlayer()
    } operation: {
      SongPreviewPlayer()
    }
    let song = blockWithoutDownloadUrl(block("1"))

    await player.toggle(song)

    #expect(!player.isActive(song))
    #expect(!player.isPlayButtonEnabled(for: song))
  }

  @Test func toggleReportsPlaybackError() async {
    struct PreviewError: Error {}
    let reported = LockIsolated<[String]>([])
    let client = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { false },
      startPlayback: { _, _ in throw PreviewError() }
    )
    let player = withDependencies {
      $0.audioPlayer = client
    } operation: {
      SongPreviewPlayer()
    }
    player.onPlaybackError = { message in reported.withValue { $0.append(message) } }
    let song = block("1")

    await player.toggle(song)

    #expect(!player.isActive(song))
    #expect(reported.value.count == 1)
  }
}
