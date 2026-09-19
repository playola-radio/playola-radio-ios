//
//  APIClientLiveShowTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 9/18/26.
//

import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct APIClientLiveShowTests {
  @Test func parsesDelayUntilFromConflictEnvelope() throws {
    let json = Data(
      """
      { "error": { "message": "Not yet", "data": { "delayUntil": "2026-09-18T18:30:00.000Z" } } }
      """.utf8)
    let delayUntil = parseLiveShowDelayUntil(from: json)
    #expect(delayUntil != nil)
  }

  @Test func delayUntilNilWhenAbsent() {
    let json = Data(#"{ "error": { "message": "An unfinished live show exists" } }"#.utf8)
    #expect(parseLiveShowDelayUntil(from: json) == nil)
  }
}
