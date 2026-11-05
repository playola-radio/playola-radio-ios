//
//  DevicePoseTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct DevicePoseTests {
  @Test
  func testHeldUprightIsUpright() {
    expectNoDifference(DevicePose(gravityX: 0.05, gravityY: -0.98), .upright)
  }

  @Test
  func testHeldUpsideDownIsUpsideDown() {
    expectNoDifference(DevicePose(gravityX: -0.05, gravityY: 0.98), .upsideDown)
  }

  @Test
  func testUpsideDownTiltedTowardTheMouthIsStillUpsideDown() {
    expectNoDifference(DevicePose(gravityX: 0.1, gravityY: 0.7), .upsideDown)
  }

  @Test
  func testFlatOnATableIsIndeterminate() {
    expectNoDifference(DevicePose(gravityX: 0.02, gravityY: 0.03), .indeterminate)
  }

  @Test
  func testLandscapeIsIndeterminate() {
    expectNoDifference(DevicePose(gravityX: 0.97, gravityY: 0.2), .indeterminate)
  }

  @Test
  func testDiagonalWhereXDominatesIsIndeterminate() {
    expectNoDifference(DevicePose(gravityX: 0.72, gravityY: 0.68), .indeterminate)
  }

  @Test
  func testJustUnderTheThresholdIsIndeterminate() {
    expectNoDifference(DevicePose(gravityX: 0, gravityY: -0.6), .indeterminate)
  }
}
