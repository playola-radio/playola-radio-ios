//
//  StationCategoryProgressTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct StationCategoryProgressTests {

  @Test
  func decodesCategoryProgressWithNullableFields() throws {
    let json = Data(
      #"""
      {
        "usesCategoryProgress": true,
        "readiness": 0.42,
        "categories": [
          { "id": "cat-1", "name": "Fan Spotlights", "audioBlockType": "voicetrack",
            "minimumCount": 5, "burnoutCount": null, "audioBlockCount": 2, "sortOrder": 0 }
        ]
      }
      """#.utf8)

    let response = try JSONDecoder().decode(StationCategoryProgressResponse.self, from: json)

    expectNoDifference(
      response,
      StationCategoryProgressResponse(
        usesCategoryProgress: true,
        readiness: 0.42,
        categories: [
          StationCategoryProgress(
            id: "cat-1",
            name: "Fan Spotlights",
            audioBlockType: .voicetrack,
            minimumCount: 5,
            burnoutCount: nil,
            audioBlockCount: 2,
            sortOrder: 0)
        ]
      ))
  }

  @Test
  func decodesUnrecognizedAudioBlockTypeAsUnknown() throws {
    let json = Data(
      #"""
      { "id": "cat-2", "name": "Mystery", "audioBlockType": "some-new-type",
        "minimumCount": 1, "burnoutCount": 10, "audioBlockCount": 0, "sortOrder": 1 }
      """#.utf8)

    let category = try JSONDecoder().decode(StationCategoryProgress.self, from: json)

    expectNoDifference(category.audioBlockType, .unknown)
    expectNoDifference(category.burnoutCount, 10)
  }
}
