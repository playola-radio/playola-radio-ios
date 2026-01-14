//
//  LiveStationInfo.swift
//  PlayolaRadio
//
//  Created by Brian Keane on 1/14/26.
//

import Foundation
import PlayolaPlayer

enum LiveStatus: String, Codable, Equatable, Sendable {
  case voicetracking
  case showAiring = "show_airing"
}

struct LiveStationInfo: Codable, Equatable, Identifiable, Sendable {
  let stationId: String
  let liveStatus: LiveStatus
  let station: Station

  var id: String { stationId }
}
