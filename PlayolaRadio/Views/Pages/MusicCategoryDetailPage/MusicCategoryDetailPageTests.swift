//
//  MusicCategoryDetailPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct MusicCategoryDetailPageTests {

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

  // MARK: - Display

  @Test func navigationTitleIsTheProvidedTitle() {
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [])

    expectNoDifference(model.navigationTitle, "Texas Country")
  }

  @Test func showsEmptyStateWhenNoSongs() {
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [])

    #expect(model.showsEmptyState)
    expectNoDifference(model.emptyStateOpacity, 1)
  }

  @Test func hidesEmptyStateWhenSongsPresent() {
    let model = MusicCategoryDetailPageModel(
      title: "Texas Country", songs: [.mockWith(id: "a")])

    #expect(!model.showsEmptyState)
    expectNoDifference(model.emptyStateOpacity, 0)
  }

  @Test func exposesSongTitleAndSubtitle() {
    let block = AudioBlock.mockWith(id: "a", title: "Whiskey Sunset", artist: "Bri Bagwell")
    let model = MusicCategoryDetailPageModel(title: "Texas Country", songs: [block])

    expectNoDifference(model.songTitle(for: block), "Whiskey Sunset")
    expectNoDifference(model.songSubtitle(for: block), "Bri Bagwell")
  }

  @Test func durationTextFormatsDurationMS() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Short", durationMS: 18_000),
        .mockWith(id: "2", title: "Long", durationMS: 84_000),
      ])

    expectNoDifference(model.durationText(for: model.songs[0]), "0:18")
    expectNoDifference(model.durationText(for: model.songs[1]), "1:24")
  }

  // MARK: - Sort

  @Test func displayedSongsDefaultsToTitleSort() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Zydeco", artist: "Bri Bagwell"),
        .mockWith(id: "2", title: "Acoustic", artist: "Charley Crockett"),
        .mockWith(id: "3", title: "Memphis", artist: "Aaron Watson"),
      ])

    expectNoDifference(model.sortMode, .title)
    expectNoDifference(model.displayedSongs.map(\.id), ["2", "3", "1"])
  }

  @Test func sortModeTappedArtistSortsByArtistThenTitle() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Whiskey", artist: "Bri Bagwell"),
        .mockWith(id: "2", title: "Boots", artist: "Bri Bagwell"),
        .mockWith(id: "3", title: "Memphis", artist: "Aaron Watson"),
      ])

    model.sortModeTapped(.artist)

    expectNoDifference(model.sortMode, .artist)
    expectNoDifference(model.displayedSongs.map(\.id), ["3", "2", "1"])
  }

  @Test func availableSectionLettersReflectTitleSort() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Acoustic", artist: "Zed"),
        .mockWith(id: "2", title: "acorn", artist: "Yon"),
        .mockWith(id: "3", title: "Memphis", artist: "Xavier"),
      ])

    expectNoDifference(model.availableSectionLetters, ["A", "M"])
  }

  @Test func availableSectionLettersReflectArtistSort() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Acoustic", artist: "Zed"),
        .mockWith(id: "2", title: "Boots", artist: "Aaron"),
      ])

    model.sortModeTapped(.artist)

    expectNoDifference(model.availableSectionLetters, ["A", "Z"])
  }

  @Test func firstSongIdForLetterUsesTitleSortKey() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Memphis", artist: "Zed"),
        .mockWith(id: "2", title: "Marfa", artist: "Yon"),
        .mockWith(id: "3", title: "Austin", artist: "Xavier"),
      ])

    expectNoDifference(model.firstSongId(forLetter: "M"), "2")
    expectNoDifference(model.firstSongId(forLetter: "A"), "3")
    #expect(model.firstSongId(forLetter: "Q") == nil)
  }

  @Test func firstSongIdForLetterUsesArtistSortKeyWhenSortingByArtist() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [
        .mockWith(id: "1", title: "Memphis", artist: "Zed"),
        .mockWith(id: "2", title: "Marfa", artist: "Aaron"),
      ])

    model.sortModeTapped(.artist)

    expectNoDifference(model.firstSongId(forLetter: "A"), "2")
    expectNoDifference(model.firstSongId(forLetter: "Z"), "1")
  }

  @Test func sortSegmentTitlesAndSelection() {
    let model = MusicCategoryDetailPageModel(title: "All Songs", songs: [])

    expectNoDifference(model.sortSegmentTitle(for: .title), "Title")
    expectNoDifference(model.sortSegmentTitle(for: .artist), "Artist")
    #expect(model.isSortSelected(.title))
    #expect(!model.isSortSelected(.artist))

    model.sortModeTapped(.artist)

    #expect(!model.isSortSelected(.title))
    #expect(model.isSortSelected(.artist))
  }

  @Test func sortSegmentColorsFollowSelection() {
    let model = MusicCategoryDetailPageModel(title: "All Songs", songs: [])

    expectNoDifference(model.sortSegmentBackgroundColor(for: .title), Color(hex: "#444444"))
    expectNoDifference(model.sortSegmentBackgroundColor(for: .artist), .clear)
    expectNoDifference(model.sortSegmentTextColor(for: .title), .white)
    expectNoDifference(model.sortSegmentTextColor(for: .artist), .playolaGray)
  }

  // MARK: - Active / inactive layout

  @Test func inactiveSongShowsRestState() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs", songs: [.mockWith(id: "1", durationMS: 18_000)])
    let block = model.songs[0]

    expectNoDifference(model.progress(for: block), 0)
    expectNoDifference(model.elapsedText(for: block), "0:00")
    #expect(!model.isActive(block))
    #expect(!model.isPlaying(block))
    expectNoDifference(model.playButtonIcon(for: block), "play.fill")
    expectNoDifference(model.playButtonBackgroundColor(for: block), Color(hex: "#444444"))
    expectNoDifference(model.trailingDurationOpacity(for: block), 1)
    expectNoDifference(model.scrubberOpacity(for: block), 0)
    expectNoDifference(model.scrubberAreaHeight(for: block), 0)
  }

  @Test func activeSongRevealsScrubberAndHidesTrailingDuration() async {
    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)

    #expect(model.isActive(block))
    expectNoDifference(model.playButtonIcon(for: block), "pause.fill")
    expectNoDifference(model.playButtonBackgroundColor(for: block), .playolaRed)
    expectNoDifference(model.trailingDurationOpacity(for: block), 0)
    expectNoDifference(model.scrubberOpacity(for: block), 1)
    expectNoDifference(model.scrubberAreaHeight(for: block), 26)
  }

  // MARK: - Playback

  @Test func playButtonTappedActivatesSong() async {
    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)

    #expect(model.isActive(block))
    #expect(model.isPlaying(block))
  }

  @Test func tappingActiveSongStopsPlayback() async {
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

    let model = withDependencies {
      $0.audioPlayer = stoppingPlayer
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))

    await model.playButtonTapped(block)

    #expect(!model.isActive(block))
    #expect(!model.isPlaying(block))
    #expect(sessionStopped.value)
  }

  @Test func tappingDifferentSongSwitchesActiveSong() async {
    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 24)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3")),
          .mockWith(
            id: "2", durationMS: 24_000, downloadUrl: URL(string: "https://example.com/2.mp3")),
        ])
    }
    let firstBlock = model.songs[0]
    let secondBlock = model.songs[1]

    await model.playButtonTapped(firstBlock)
    await model.playButtonTapped(secondBlock)

    #expect(!model.isActive(firstBlock))
    #expect(model.isActive(secondBlock))
  }

  @Test func tappingCompletedSongReplaysInsteadOfConsumingTap() async {
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

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isPlaying(block))

    callbackBox.value?(PlaybackState(currentTime: 18, duration: 18, isPlaying: false))
    #expect(!model.isPlaying(block))
    #expect(!model.isActive(block))

    await model.playButtonTapped(block)

    #expect(model.isPlaying(block))
    expectNoDifference(started.value, ["1.mp3", "1.mp3"])
  }

  @Test func nearEndTickWhileStillPlayingDoesNotResetSong() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 1, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))

    callbackBox.value?(PlaybackState(currentTime: 17.91, duration: 18, isPlaying: true))

    #expect(model.isActive(block))
    #expect(model.isPlaying(block))
  }

  @Test func bufferingStallMidPlaybackDoesNotResetSong() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 1, duration: 18, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))

    callbackBox.value?(PlaybackState(currentTime: 1.2, duration: 18, isPlaying: false))

    #expect(model.isActive(block))
  }

  @Test func zeroDurationClipCompletesOnDidFinish() async {
    let callbackBox = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 0 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 0, isPlaying: true))
        callbackBox.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    )

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(id: "1", durationMS: 0, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))

    callbackBox.value?(
      PlaybackState(currentTime: 0, duration: 0, isPlaying: false, didFinish: true))

    #expect(!model.isActive(block))
  }

  @Test func negativeDurationDoesNotProduceNegativeSeek() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 0 }, isPlaying: { true },
      startPlayback: { _, onStateChange in
        await onStateChange(PlaybackState(currentTime: 0, duration: 0, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {}, stop: {},
          seek: { target in seekedTo.withValue { $0.append(target) } }, cancel: {})
      }
    )

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: -5000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    await model.scrubberDragged(block, locationX: 25, trackWidth: 100)

    #expect(seekedTo.value.allSatisfy { $0 >= 0 })
  }

  @Test func tappingDuringStartupBeforePlaybackCallbackStopsNotRestarts() async {
    let started = LockIsolated<[String]>([])
    let sessionStopped = LockIsolated(false)
    let player = AudioPlayerClient(
      loadFile: { _ in }, play: {}, pause: {}, stop: {}, seek: { _ in },
      currentTime: { 0 }, duration: { 18 }, isPlaying: { true },
      startPlayback: { url, _ in
        started.withValue { $0.append(url.lastPathComponent) }
        return PlaybackSession(
          play: {}, pause: {},
          stop: { sessionStopped.setValue(true) },
          seek: { _ in }, cancel: {})
      }
    )

    let model = withDependencies {
      $0.audioPlayer = player
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    #expect(model.isActive(block))
    #expect(!model.isPlaying(block))
    // During startup the tap toggle stops, so the icon must read "pause.fill" even though
    // isPlaying is still false.
    expectNoDifference(model.playButtonIcon(for: block), "pause.fill")

    await model.playButtonTapped(block)

    #expect(!model.isActive(block))
    #expect(sessionStopped.value)
    expectNoDifference(started.value, ["1.mp3"])
  }

  @Test func scrubberAccessibilityLabelAndValueReflectSong() {
    let model = MusicCategoryDetailPageModel(
      title: "All Songs",
      songs: [.mockWith(id: "1", title: "Whiskey", durationMS: 18_000)])
    let block = model.songs[0]

    expectNoDifference(
      model.scrubberAccessibilityLabel(for: block), "\(model.songTitle(for: block)) scrubber")
    expectNoDifference(model.scrubberAccessibilityValue(for: block), "0:00 of 0:18")
  }

  @Test func scrubberAdjustedSeeksForwardWhenActive() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let model = withDependencies {
      $0.audioPlayer = makeSeekRecordingPlayer(seekedTo: seekedTo)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    await model.scrubberAdjusted(block, increment: true)

    expectNoDifference(seekedTo.value, [5])
  }

  @Test func scrubberAdjustedIsNoOpWhenInactive() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let model = withDependencies {
      $0.audioPlayer = makeSeekRecordingPlayer(seekedTo: seekedTo)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.scrubberAdjusted(block, increment: true)

    #expect(seekedTo.value.isEmpty)
  }

  @Test func scrubberDraggedSeeksToProportionalPositionWhenActive() async {
    let seekedTo = LockIsolated<[TimeInterval]>([])
    let model = withDependencies {
      $0.audioPlayer = makeSeekRecordingPlayer(seekedTo: seekedTo, duration: 20)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 20_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    await model.scrubberDragged(block, locationX: 50, trackWidth: 100)

    expectNoDifference(seekedTo.value, [10])
  }

  @Test func viewDisappearedStopsPlayback() async {
    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      MusicCategoryDetailPageModel(
        title: "All Songs",
        songs: [
          .mockWith(
            id: "1", durationMS: 18_000, downloadUrl: URL(string: "https://example.com/1.mp3"))
        ])
    }
    let block = model.songs[0]

    await model.playButtonTapped(block)
    await model.viewDisappeared()

    #expect(!model.isActive(block))
  }

  @Test func playButtonTappedWithNilDownloadUrlIsNoOp() async {
    let block = blockWithoutDownloadUrl(.mockWith(id: "1", durationMS: 18_000))

    let model = withDependencies {
      $0.audioPlayer = makePlayingAudioPlayer(duration: 18)
    } operation: {
      MusicCategoryDetailPageModel(title: "All Songs", songs: [block])
    }

    await model.playButtonTapped(block)

    #expect(!model.isActive(block))
  }

  @Test func playButtonIsDisabledForSongWithoutDownloadUrl() {
    let noUrl = blockWithoutDownloadUrl(.mockWith(id: "1"))
    let playable = AudioBlock.mockWith(
      id: "2", downloadUrl: URL(string: "https://example.com/2.mp3"))
    let model = MusicCategoryDetailPageModel(title: "All Songs", songs: [noUrl, playable])

    #expect(!model.isPlayButtonEnabled(for: noUrl))
    #expect(model.isPlayButtonEnabled(for: playable))
  }
}
