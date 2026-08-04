//
//  SingleNowPlayingWriterTests.swift
//  PlayolaRadio
//
//  Structural guard for Phase 2 of the audio-ownership refactor: NowPlayingUpdater
//  is the ONLY writer of MPNowPlayingInfoCenter. A second writer (historically
//  URLStreamPlayer) clobbers the Now Playing dict and produces the wrong lock
//  screen. This scans the app source tree and fails if MPNowPlayingInfoCenter is
//  referenced anywhere except NowPlayingUpdater.swift.
//

import Foundation
import Testing

@Suite(.freshSharedState)
@MainActor
struct SingleNowPlayingWriterTests {
  @Test
  func onlyNowPlayingUpdaterReferencesNowPlayingCenter() throws {
    let offenders = try appSwiftFilesContaining(
      "MPNowPlayingInfoCenter",
      allowedRelativePaths: ["Core/AudioPlayback/NowPlayingUpdater/NowPlayingUpdater.swift"])

    #expect(
      offenders.isEmpty,
      "MPNowPlayingInfoCenter must be written only by NowPlayingUpdater; found in: \(offenders)")
  }

  // Structural guard for Phase 3: StationPlayer is the ONLY writer of
  // `@Shared(.nowPlaying)`. A second writer (historically NowPlayingUpdater's
  // duplicated backend processors) can drift from `StationPlayer.state`, so the
  // lock screen and in-app UI disagree. This scans the app source tree and fails
  // if `$nowPlaying.withLock` appears anywhere except StationPlayer.swift.
  @Test
  func onlyStationPlayerWritesSharedNowPlaying() throws {
    let offenders = try appSwiftFilesContaining(
      "$nowPlaying.withLock",
      allowedRelativePaths: ["Core/AudioPlayback/StationPlayer.swift"])

    #expect(
      offenders.isEmpty,
      "@Shared(.nowPlaying) must be written only by StationPlayer; found in: \(offenders)")
  }

  /// Relative paths of every app-source Swift file (excluding `*Tests.swift` and
  /// the allowlist) that contains `needle`. This file lives at
  /// `PlayolaRadio/Core/AudioPlayback/<file>`; walk up three levels to the
  /// app-source root. Allowlisting by resolved relative path — not basename —
  /// avoids silently skipping a same-named file elsewhere in the tree.
  ///
  /// The needle is the exact write idiom (`$nowPlaying.withLock` /
  /// `MPNowPlayingInfoCenter`), not the `@Shared` key: several files legitimately
  /// declare `@Shared(.nowPlaying)` to *read* it (and some also `.withLock` other
  /// keys), so a key-based match would false-positive on readers.
  private func appSwiftFilesContaining(
    _ needle: String,
    allowedRelativePaths: Set<String>
  ) throws -> [String] {
    let appSourceRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // AudioPlayback
      .deletingLastPathComponent()  // Core
      .deletingLastPathComponent()  // PlayolaRadio

    let enumerator = try #require(
      FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil),
      "Could not enumerate app source root at \(appSourceRoot.path)")

    var offenders: [String] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
      guard !url.lastPathComponent.hasSuffix("Tests.swift") else { continue }
      let relativePath = url.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")
      guard !allowedRelativePaths.contains(relativePath) else { continue }
      let content = try String(contentsOf: url, encoding: .utf8)
      if content.contains(needle) {
        offenders.append(relativePath)
      }
    }
    return offenders
  }
}
