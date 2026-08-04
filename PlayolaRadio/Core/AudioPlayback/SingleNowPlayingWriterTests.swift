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
struct SingleNowPlayingWriterTests {
  @Test
  func onlyNowPlayingUpdaterReferencesNowPlayingCenter() throws {
    // This file lives at PlayolaRadio/Core/AudioPlayback/<file>; walk up three
    // levels to the PlayolaRadio app-source root and scan every Swift file under it.
    let appSourceRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // AudioPlayback
      .deletingLastPathComponent()  // Core
      .deletingLastPathComponent()  // PlayolaRadio

    let enumerator = try #require(
      FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil),
      "Could not enumerate app source root at \(appSourceRoot.path)")

    // Allowlist by resolved relative path, not basename — a basename match would
    // silently skip any other file named NowPlayingUpdater.swift elsewhere in the
    // tree, letting a second writer slip past the guard.
    let allowedRelativePaths: Set<String> = [
      "Core/AudioPlayback/NowPlayingUpdater/NowPlayingUpdater.swift"
    ]

    var offenders: [String] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
      guard !url.lastPathComponent.hasSuffix("Tests.swift") else { continue }
      let relativePath = url.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")
      guard !allowedRelativePaths.contains(relativePath) else { continue }
      let content = try String(contentsOf: url, encoding: .utf8)
      if content.contains("MPNowPlayingInfoCenter") {
        offenders.append(relativePath)
      }
    }

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
    let appSourceRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // AudioPlayback
      .deletingLastPathComponent()  // Core
      .deletingLastPathComponent()  // PlayolaRadio

    let enumerator = try #require(
      FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil),
      "Could not enumerate app source root at \(appSourceRoot.path)")

    // Allowlist by resolved relative path, not basename — see the sibling test.
    let allowedRelativePaths: Set<String> = [
      "Core/AudioPlayback/StationPlayer.swift"
    ]

    var offenders: [String] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
      guard !url.lastPathComponent.hasSuffix("Tests.swift") else { continue }
      let relativePath = url.path.replacingOccurrences(of: appSourceRoot.path + "/", with: "")
      guard !allowedRelativePaths.contains(relativePath) else { continue }
      let content = try String(contentsOf: url, encoding: .utf8)
      if content.contains("$nowPlaying.withLock") {
        offenders.append(relativePath)
      }
    }

    #expect(
      offenders.isEmpty,
      "@Shared(.nowPlaying) must be written only by StationPlayer; found in: \(offenders)")
  }
}
