//
//  CarPlayPlaybackTransition.swift
//  PlayolaRadio
//
//  Pure, testable decision logic for which CarPlay template should be shown for
//  a given playback status. Extracted from CarPlaySceneDelegate so the
//  push/pop/dismiss decision can be unit tested without a system-provided
//  CPInterfaceController.
//

enum CarPlayPlaybackTransition {
  /// The template change CarPlay should make in response to a playback status.
  enum Action: Equatable {
    /// Ensure the Now Playing template is the visible (top) template.
    case showNowPlaying
    /// Remove the Now Playing template, returning to the station list.
    case removeNowPlaying
    /// Present the "unable to connect" error alert.
    case showError
    /// No template change. `action(for:)` does not emit this today (every
    /// `PlaybackStatus` maps to a concrete action); it exists so callers have an
    /// explicit no-op branch and so new statuses can opt out of a template change.
    case none
  }

  /// Maps a playback status to the template action CarPlay should take.
  ///
  /// Critically, `.playing` maps to `.showNowPlaying` (not `.none`). An earlier
  /// version did nothing on `.playing`, so any spurious `.stopped` that arrived
  /// after Now Playing was shown dismissed it permanently — the user was stuck
  /// on the station list. Showing Now Playing on `.playing` makes the
  /// transition self-healing.
  static func action(for playbackStatus: StationPlayer.PlaybackStatus) -> Action {
    switch playbackStatus {
    case .error:
      return .showError
    case .loading, .startingNewStation, .playing:
      return .showNowPlaying
    case .stopped:
      return .removeNowPlaying
    }
  }
}
