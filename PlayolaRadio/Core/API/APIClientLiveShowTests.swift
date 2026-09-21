//
//  APIClientLiveShowTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 9/18/26.
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct APIClientLiveShowTests {
  @Test func parsesDelayUntilFromConflictEnvelope() throws {
    let json = Data(
      """
      { "error": { "message": "Not yet", "data": { "delayUntil": "2026-09-18T18:30:00.123Z" } } }
      """.utf8)
    let delayUntil = try #require(parseLiveShowDelayUntil(from: json))
    expectNoDifference(delayUntil, Date(timeIntervalSince1970: 1_789_756_200.123))
  }

  @Test func delayUntilNilWhenAbsent() {
    let json = Data(#"{ "error": { "message": "An unfinished live show exists" } }"#.utf8)
    #expect(parseLiveShowDelayUntil(from: json) == nil)
  }
}
