//
//  VersionComparisonTests.swift
//  PlayolaRadio
//

import Testing

@testable import PlayolaRadio

@MainActor
struct VersionComparisonTests {
  @Test
  func testEqualVersionsReturnsFalse() {
    #expect(!isVersion("1.0.0", lessThan: "1.0.0"))
  }

  @Test
  func testLessThanMajorReturnsTrue() {
    #expect(isVersion("1.0.0", lessThan: "2.0.0"))
  }

  @Test
  func testGreaterThanMajorReturnsFalse() {
    #expect(!isVersion("2.0.0", lessThan: "1.0.0"))
  }

  @Test
  func testLessThanMinorReturnsTrue() {
    #expect(isVersion("1.1.0", lessThan: "1.2.0"))
  }

  @Test
  func testGreaterThanMinorReturnsFalse() {
    #expect(!isVersion("1.2.0", lessThan: "1.1.0"))
  }

  @Test
  func testLessThanPatchReturnsTrue() {
    #expect(isVersion("1.0.1", lessThan: "1.0.2"))
  }

  @Test
  func testGreaterThanPatchReturnsFalse() {
    #expect(!isVersion("1.0.2", lessThan: "1.0.1"))
  }

  @Test
  func testMissingPatchTreatedAsZero() {
    #expect(!isVersion("1.0", lessThan: "1.0.0"))
    #expect(isVersion("1.0", lessThan: "1.0.1"))
  }

  @Test
  func testMissingPatchOnRequiredTreatedAsZero() {
    #expect(!isVersion("1.0.0", lessThan: "1.0"))
    #expect(!isVersion("1.0.1", lessThan: "1.0"))
  }

  @Test
  func testTwoComponentVersions() {
    #expect(isVersion("1.0", lessThan: "1.1"))
    #expect(!isVersion("1.1", lessThan: "1.0"))
  }
}
