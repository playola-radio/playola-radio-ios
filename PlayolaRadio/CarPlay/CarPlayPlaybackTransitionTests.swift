//
//  CarPlayPlaybackTransitionTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@MainActor
struct CarPlayPlaybackTransitionTests {

  // Regression for the CarPlay "Now Playing is instantly dismissed" bug: while
  // a station is playing, CarPlay must keep showing Now Playing. The previous
  // implementation did nothing on `.playing`, so once any stray `.stopped`
  // dismissed Now Playing it was never restored and the user stayed on the list.
  @Test
  func testPlayingShowsNowPlaying() {
    expectNoDifference(
      CarPlayPlaybackTransition.action(for: .playing(.mock)),
      .showNowPlaying
    )
  }

  @Test
  func testLoadingShowsNowPlaying() {
    expectNoDifference(
      CarPlayPlaybackTransition.action(for: .loading(.mock)),
      .showNowPlaying
    )
  }

  @Test
  func testStartingNewStationShowsNowPlaying() {
    expectNoDifference(
      CarPlayPlaybackTransition.action(for: .startingNewStation(.mock)),
      .showNowPlaying
    )
  }

  @Test
  func testStoppedRemovesNowPlaying() {
    expectNoDifference(
      CarPlayPlaybackTransition.action(for: .stopped),
      .removeNowPlaying
    )
  }

  @Test
  func testErrorShowsError() {
    expectNoDifference(
      CarPlayPlaybackTransition.action(for: .error),
      .showError
    )
  }
}
