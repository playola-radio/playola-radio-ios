//
//  StationSetupProgressTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct StationSetupProgressTests {

  @Test
  func decodesSetupProgressIgnoringUnmodeledCategoryVersion() throws {
    let json = Data(
      #"""
      {
        "stationId": "station-1",
        "categoryVersion": { "kind": "draft", "id": null },
        "progress": 0.47,
        "displayPercentage": 47,
        "factors": {
          "sourceTapes": { "current": 1, "required": 3, "progress": 0.33, "weight": 0.6 },
          "welcome":     { "current": 1, "required": 1, "progress": 1.0,  "weight": 0.05 },
          "songs":       { "current": 341, "required": 505, "progress": 0.675, "weight": 0.15 },
          "breakers":    { "current": 135, "required": 245, "progress": 0.55, "weight": 0.2 }
        }
      }
      """#.utf8)

    let setupProgress = try JSONDecoder().decode(StationSetupProgress.self, from: json)

    expectNoDifference(
      setupProgress,
      StationSetupProgress(
        stationId: "station-1",
        progress: 0.47,
        displayPercentage: 47,
        factors: StationSetupProgress.Factors(
          sourceTapes: StationSetupProgress.Factor(
            current: 1, required: 3, progress: 0.33, weight: 0.6),
          welcome: StationSetupProgress.Factor(
            current: 1, required: 1, progress: 1.0, weight: 0.05),
          songs: StationSetupProgress.Factor(
            current: 341, required: 505, progress: 0.675, weight: 0.15),
          breakers: StationSetupProgress.Factor(
            current: 135, required: 245, progress: 0.55, weight: 0.2)
        )
      ))
  }
}
