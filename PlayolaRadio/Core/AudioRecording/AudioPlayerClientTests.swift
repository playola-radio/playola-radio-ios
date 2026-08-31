//
//  AudioPlayerClientTests.swift
//  PlayolaRadio
//

import Foundation
import Testing

@testable import PlayolaRadio

struct PlaybackStateTests {
  @Test func isCompleteTrueWhenDidFinish() {
    let state = PlaybackState(currentTime: 0, duration: 0, isPlaying: false, didFinish: true)
    #expect(state.isComplete)
  }

  @Test func isCompleteTrueAtNearEndProgress() {
    let state = PlaybackState(currentTime: 17.5, duration: 18, isPlaying: false)
    #expect(state.isComplete)
  }

  @Test func isCompleteFalseMidSong() {
    let state = PlaybackState(currentTime: 9, duration: 18, isPlaying: false)
    #expect(!state.isComplete)
  }

  @Test func isCompleteFalseForZeroDurationWithoutDidFinish() {
    let state = PlaybackState(currentTime: 0, duration: 0, isPlaying: false)
    #expect(!state.isComplete)
  }

  @Test func idleIsNotComplete() {
    #expect(!PlaybackState.idle.isComplete)
    #expect(!PlaybackState.idle.didFinish)
  }
}

struct AudioPlaybackMathDetectEndTests {
  @Test func neverPlayedIsNotEnd() {
    #expect(
      !AudioPlaybackMath.detectEnd(
        hasPlayed: false, isPlaying: false, currentTime: 0, duration: 18))
  }

  @Test func stillPlayingIsNotEnd() {
    #expect(
      !AudioPlaybackMath.detectEnd(
        hasPlayed: true, isPlaying: true, currentTime: 18, duration: 18))
  }

  @Test func midSongStallIsNotEnd() {
    #expect(
      !AudioPlaybackMath.detectEnd(
        hasPlayed: true, isPlaying: false, currentTime: 4, duration: 18))
  }

  @Test func stoppedAtEndIsEnd() {
    #expect(
      AudioPlaybackMath.detectEnd(
        hasPlayed: true, isPlaying: false, currentTime: 17.9, duration: 18))
  }

  // A zero/unknown duration has no reliable poll-based end signal, so not-playing there is NOT
  // treated as the end (otherwise the first pause or pre-roll buffering gap would look complete).
  @Test func zeroDurationPlayedThenStoppedIsNotEnd() {
    #expect(
      !AudioPlaybackMath.detectEnd(
        hasPlayed: true, isPlaying: false, currentTime: 0, duration: 0))
  }

  // A user pausing a normal (positive-duration) clip mid-track must not read as completion.
  @Test func pausedMidPositiveDurationIsNotEnd() {
    #expect(
      !AudioPlaybackMath.detectEnd(
        hasPlayed: true, isPlaying: false, currentTime: 9, duration: 18))
  }
}

struct AudioPlaybackMathClampSeekTests {
  @Test func negativeTargetClampsToZero() {
    #expect(AudioPlaybackMath.clampSeekTarget(-5, duration: 18) == 0)
  }

  @Test func targetBeyondDurationClampsToDuration() {
    #expect(AudioPlaybackMath.clampSeekTarget(99, duration: 18) == 18)
  }

  @Test func inRangeTargetIsUnchanged() {
    #expect(AudioPlaybackMath.clampSeekTarget(7, duration: 18) == 7)
  }

  @Test func nonFiniteTargetIsRejected() {
    #expect(AudioPlaybackMath.clampSeekTarget(.infinity, duration: 18) == nil)
    #expect(AudioPlaybackMath.clampSeekTarget(.nan, duration: 18) == nil)
  }

  @Test func unknownDurationFloorsAtZero() {
    #expect(AudioPlaybackMath.clampSeekTarget(-5, duration: 0) == 0)
    #expect(AudioPlaybackMath.clampSeekTarget(42, duration: 0) == 42)
  }
}
