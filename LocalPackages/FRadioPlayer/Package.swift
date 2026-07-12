// swift-tools-version: 5.9
import PackageDescription

// Playola's vendored + stripped fork of fethica/FRadioPlayer (v0.2.1).
//
// Why a local package instead of files in the app target: FRadioPlayer is
// unmaintained third-party code that trips the app target's strict settings
// (SWIFT_STRICT_CONCURRENCY=complete + SWIFT_TREAT_WARNINGS_AS_ERRORS=YES) and
// uses APIs deprecated after its last release. A SwiftPM target compiles with
// its OWN settings (Swift 5 language mode, default/minimal concurrency checking,
// no warnings-as-errors), so the code builds exactly as it did upstream and is
// immune to the app's strictness and to future Xcode strictness bumps.
//
// Stripped from upstream (see git history / Phase 1 Task 1.2): the init-time
// AVAudioSession.setCategory call and the self-owned interruption/route
// observers. The app's AudioSessionCoordinator is the single owner of the
// AVAudioSession and interruption policy now.
let package = Package(
  name: "FRadioPlayer",
  platforms: [.iOS(.v16)],
  products: [
    .library(name: "FRadioPlayer", targets: ["FRadioPlayer"])
  ],
  targets: [
    .target(name: "FRadioPlayer")
  ]
)
