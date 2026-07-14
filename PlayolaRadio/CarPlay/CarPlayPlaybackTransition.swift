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
    case .loading, .startingNewStation, .playing, .paused:
      return .showNowPlaying
    case .stopped:
      return .removeNowPlaying
    }
  }

  /// The distinct CarPlay actions for a sequence of playback statuses, collapsing
  /// consecutive duplicates — the exact policy the live `$state` observer applies
  /// via `.map(action(for:)).removeDuplicates()`.
  ///
  /// Deduping on the *status* (as the observer originally did) fails to collapse
  /// the `.loading(station, progress)` stream, because the progress `Float` makes
  /// every buffering tick a distinct status. Deduping on the *action* collapses
  /// the whole flood to one `.showNowPlaying`, so `CPNowPlayingTemplate.shared` is
  /// pushed once instead of hundreds of times (each re-push is rejected by CarPlay
  /// with "Pushing the same template instance more than once", which stranded the
  /// user on the station list).
  ///
  /// Exposed so that invariant can be unit-tested without a system
  /// `CPInterfaceController`.
  static func distinctActions(for statuses: [StationPlayer.PlaybackStatus]) -> [Action] {
    var result: [Action] = []
    for status in statuses {
      let next = action(for: status)
      if result.last != next { result.append(next) }
    }
    return result
  }
}
