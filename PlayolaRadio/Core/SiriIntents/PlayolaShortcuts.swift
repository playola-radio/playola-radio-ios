import AppIntents

struct PlayolaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PlayStationIntent(),
      phrases: [
        "Play \(\.$station) on \(.applicationName)",
        "Start \(\.$station) on \(.applicationName)",
      ],
      shortTitle: "Play Station",
      systemImageName: "radio"
    )
  }
}
