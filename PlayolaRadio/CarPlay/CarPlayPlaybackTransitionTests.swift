//
//  CarPlayPlaybackTransitionTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
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

  // Regression for the CarPlay "stuck on the station list" bug: the Playola SDK
  // streams `.loading(station, progress)` with a changing progress float on every
  // buffering tick. The live observer must dedupe on the *action*, not the raw
  // status, so the whole loading flood collapses to a single `.showNowPlaying`.
  // Otherwise each tick re-pushes `CPNowPlayingTemplate.shared` and CarPlay rejects
  // it with "Pushing the same template instance more than once".
  @Test
  func testLoadingProgressFloodCollapsesToSingleShowNowPlaying() {
    let statuses: [StationPlayer.PlaybackStatus] = [
      .stopped,
      .startingNewStation(.mock),
      .loading(.mock, 0.02),
      .loading(.mock, 0.19),
      .loading(.mock, 0.87),
      .playing(.mock),
    ]
    expectNoDifference(
      CarPlayPlaybackTransition.distinctActions(for: statuses),
      [.removeNowPlaying, .showNowPlaying]
    )
  }

  // A real stop between two stations must still emit a fresh `.removeNowPlaying`
  // then `.showNowPlaying` — deduping on the action must not swallow a genuine
  // transition, only the redundant progress ticks.
  @Test
  func testStationSwitchStillTogglesNowPlaying() {
    let statuses: [StationPlayer.PlaybackStatus] = [
      .playing(.mock),
      .stopped,
      .loading(.mock, 0.1),
      .loading(.mock, 0.5),
      .playing(.mock),
    ]
    expectNoDifference(
      CarPlayPlaybackTransition.distinctActions(for: statuses),
      [.showNowPlaying, .removeNowPlaying, .showNowPlaying]
    )
  }
}
