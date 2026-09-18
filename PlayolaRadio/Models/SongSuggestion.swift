//
//  SongSuggestion.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer

/// One entry from `GET /v1/stations/:stationId/song-suggestions`: a full library
/// `AudioBlock` (with `downloadUrl`, so it reuses the Search tab's preview/Add
/// machinery). The array arrives already ordered least→most burned out, so the
/// ranking is the array order and nothing else from the entry is displayed.
struct SongSuggestion: Decodable, Equatable, Sendable {
  let audioBlock: AudioBlock
}
