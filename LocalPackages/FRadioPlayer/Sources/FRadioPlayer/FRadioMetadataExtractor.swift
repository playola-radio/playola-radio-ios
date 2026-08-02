//
//  FRadioMetadataExtractor.swift
//  FRadioPlayer
//
//  Created by Fethi El Hassasna on 2022-06-07.
//

import AVFoundation

public protocol FRadioMetadataExtractor {
  func extract(from groups: [AVTimedMetadataGroup]) -> FRadioPlayer.Metadata?
}

// Default implementation
struct DefaultMetadataExtractor: FRadioMetadataExtractor {
  func extract(from groups: [AVTimedMetadataGroup]) -> FRadioPlayer.Metadata? {
    guard !groups.isEmpty else { return nil }

    let rawValue = groups.first?.items.first?.value as? String
    let rawValueCleaned = cleanRawMetadataIfNeeded(rawValue)
    // Split on the FIRST " - " only: "Artist - Song - Live" is artist "Artist"
    // and track "Song - Live", not "Live" (splitting on every delimiter dropped
    // the middle segment).
    let parts = rawValueCleaned?.components(separatedBy: " - ") ?? []
    let artistName = parts.first
    let trackName = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : nil

    return FRadioPlayer.Metadata(
      artistName: artistName, trackName: trackName, rawValue: rawValueCleaned, groups: groups)
  }

  private func cleanRawMetadataIfNeeded(_ rawValue: String?) -> String? {
    guard let rawValue = rawValue else { return nil }
    // Strip off trailing '[???]' characters left there by ShoutCast and Centova Streams
    // It will leave the string alone if the pattern is not there

    // Anchor to the END of the string so only trailing markers are stripped —
    // legitimate metadata like "Song (Live)" or "[Remastered]" mid-string is kept.
    let pattern = #"(?:\s*(?:\([^)]*\)|\[[^\]]*\]))+$"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return rawValue
    }

    let rawCleaned = NSMutableString(string: rawValue)
    regex.replaceMatches(
      in: rawCleaned, options: .reportProgress,
      range: NSRange(location: 0, length: rawCleaned.length), withTemplate: "")

    return rawCleaned as String
  }
}
