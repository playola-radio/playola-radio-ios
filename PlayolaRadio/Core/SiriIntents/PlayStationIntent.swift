import AppIntents

struct PlayStationIntent: AppIntent {
  static var title: LocalizedStringResource { "Play Station" }
  static var openAppWhenRun: Bool { true }

  @Parameter(title: "Station")
  var station: RadioStationEntity

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let outcome = await PlayStationAction().run(stationID: station.id)
    switch outcome {
    case .requiresSignIn:
      return .result(dialog: "Open Playola to sign in first")
    case .notFound:
      return .result(dialog: "I couldn't find that station on Playola")
    case .playing(let name):
      return .result(dialog: "Playing \(name)")
    }
  }
}
