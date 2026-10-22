//
//  Spin+ProgressTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/26.
//

import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct SpinProgressTests {

  private let airtime = Date(timeIntervalSince1970: 1_000_000)

  private func spin(endOfMessageMS: Int) -> Spin {
    Spin.mockWith(
      airtime: airtime,
      audioBlock: .mockWith(endOfMessageMS: endOfMessageMS)
    )
  }

  @Test func progressIsZeroAtAirtime() {
    let spin = spin(endOfMessageMS: 180_000)
    #expect(spin.progress(at: airtime) == 0)
  }

  @Test func progressIsHalfAtMidpoint() {
    let spin = spin(endOfMessageMS: 180_000)
    let midpoint = airtime.addingTimeInterval(90)
    #expect(spin.progress(at: midpoint) == 0.5)
  }

  @Test func progressClampsToOnePastEnd() {
    let spin = spin(endOfMessageMS: 180_000)
    let wellPastEnd = airtime.addingTimeInterval(10_000)
    #expect(spin.progress(at: wellPastEnd) == 1)
  }

  @Test func progressClampsToZeroBeforeAirtime() {
    let spin = spin(endOfMessageMS: 180_000)
    let beforeAirtime = airtime.addingTimeInterval(-60)
    #expect(spin.progress(at: beforeAirtime) == 0)
  }

  @Test func progressIsZeroForZeroDuration() {
    let spin = spin(endOfMessageMS: 0)
    #expect(spin.progress(at: airtime.addingTimeInterval(60)) == 0)
  }
}
