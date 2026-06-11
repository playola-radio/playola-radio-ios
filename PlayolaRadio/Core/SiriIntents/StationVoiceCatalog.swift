import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

/// A station resolved from a spoken/typed query, with the label the App Intents
/// layer shows. FM → station name; Artist → "[Artist]'s Station".
struct StationMatch: Equatable, Identifiable {
  let id: String  // AnyStation.id
  let label: String
}

@MainActor
struct StationVoiceCatalog {
  @Shared(.stationLists) var stationLists

  /// Lowercase, strip possessive "'s", strip punctuation, drop the filler words
  /// "radio"/"station", collapse whitespace. Applied to both station aliases and
  /// the incoming query so matching is symmetric.
  static func normalize(_ raw: String) -> String {
    var text = raw.lowercased()
    text = text.folding(options: .diacriticInsensitive, locale: nil)
    text = text.replacingOccurrences(of: "'s", with: "")
    text = text.replacingOccurrences(of: "\u{2019}s", with: "")  // curly apostrophe
    let allowed = CharacterSet.alphanumerics.union(.whitespaces)
    text = String(text.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " })
    let filler: Set<String> = ["radio", "station"]
    let words = text.split(separator: " ").map(String.init).filter { !filler.contains($0) }
    return words.joined(separator: " ")
  }

  /// All playable (visible, non-coming-soon) stations as matches.
  func suggestedStations() -> [StationMatch] {
    allStations().map(makeMatch(for:))
  }

  /// Best-effort fuzzy matches for a spoken/typed query, ordered best-first.
  /// Fails closed: returns [] when nothing clears the confidence bar.
  func matches(query: String) -> [StationMatch] {
    let needle = Self.normalize(query)
    guard !needle.isEmpty else { return [] }
    return allStations().enumerated().compactMap { index, station -> ScoredMatch? in
      guard let score = bestScore(for: station, needle: needle), score > 0 else { return nil }
      return ScoredMatch(match: makeMatch(for: station), score: score, catalogIndex: index)
    }
    .sorted { lhs, rhs in
      // Higher score first; break ties by catalog order for deterministic results.
      lhs.score != rhs.score ? lhs.score > rhs.score : lhs.catalogIndex < rhs.catalogIndex
    }
    .map(\.match)
  }

  /// Match for a known id (used to rehydrate an entity by id).
  func match(id: String) -> StationMatch? {
    allStations().first { $0.id == id }.map(makeMatch(for:))
  }

  /// Resolve a match id back to the real station for playback.
  func station(id: String) -> AnyStation? {
    allStations().first { $0.id == id }
  }

  // MARK: - Private

  private struct ScoredMatch {
    let match: StationMatch
    let score: Int
    let catalogIndex: Int
  }

  private func allStations() -> [AnyStation] {
    stationLists
      .filter { !$0.hidden }
      .flatMap { list in
        list.stationItems(includeHidden: false, includeComingSoon: false).map(\.anyStation)
      }
  }

  private func aliases(for station: AnyStation) -> [String] {
    switch station {
    case .url(let station): return [station.name]
    case .playola(let station):
      return [station.curatorName, "\(station.curatorName)'s Station", station.name]
    }
  }

  private func label(for station: AnyStation) -> String {
    switch station {
    case .url(let station): return station.name
    case .playola(let station): return "\(station.curatorName)'s Station"
    }
  }

  private func makeMatch(for station: AnyStation) -> StationMatch {
    StationMatch(id: station.id, label: label(for: station))
  }

  /// Exact normalized alias match beats prefix beats whole-word containment.
  /// Fails closed: fragments shorter than 3 chars, and loose mid-word substrings,
  /// score nil so a misheard syllable never confidently plays the wrong station.
  private func bestScore(for station: AnyStation, needle: String) -> Int? {
    guard needle.count >= 3 else { return nil }
    let needleWords = Set(needle.split(separator: " ").map(String.init))
    var best: Int?
    for alias in aliases(for: station) {
      let hay = Self.normalize(alias)
      guard !hay.isEmpty else { continue }
      let hayWords = Set(hay.split(separator: " ").map(String.init))
      let score: Int?
      if hay == needle {
        score = 100
      } else if hay.hasPrefix(needle) || needle.hasPrefix(hay) {
        score = 60
      } else if needleWords.isSubset(of: hayWords) || hayWords.isSubset(of: needleWords) {
        score = 40  // every word of one side appears as a whole word in the other
      } else {
        score = nil
      }
      if let score, score > (best ?? 0) { best = score }
    }
    return best
  }
}
