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
    let catalog = StationVoiceCatalog()
    guard let station = catalog.station(id: stationID) else { return .notFound }
    let label = catalog.match(id: stationID)?.label ?? station.stationName
    PlaybackBootstrap().prepareForPlayback()
    await stationPlayer.play(station: station)
    return .playing(stationName: label)
  }
}
