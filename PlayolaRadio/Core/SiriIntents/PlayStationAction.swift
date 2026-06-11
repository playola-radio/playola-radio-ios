import Dependencies
import Sharing

enum PlayStationOutcome: Equatable {
  case requiresSignIn
  case notFound
  case playing(stationName: String)
}

@MainActor
struct PlayStationAction {
  @Shared(.auth) var auth
  @Dependency(\.stationPlayer) var stationPlayer

  func run(stationID: String) async -> PlayStationOutcome {
    guard auth.isLoggedIn else { return .requiresSignIn }
    guard let station = StationVoiceCatalog().station(id: stationID) else { return .notFound }
    PlaybackBootstrap().prepareForPlayback()
    await stationPlayer.play(station: station)
    return .playing(stationName: station.stationName)
  }
}
