//
//  VersionComparisonTests.swift
//  PlayolaRadio
//

import XCTest

@testable import PlayolaRadio

@MainActor
class VersionComparisonTests: XCTestCase {
  func testEqualVersionsReturnsFalse() {
    XCTAssertFalse(isVersion("1.0.0", lessThan: "1.0.0"))
  }

  func testLessThanMajorReturnsTrue() {
    XCTAssertTrue(isVersion("1.0.0", lessThan: "2.0.0"))
  }

  func testGreaterThanMajorReturnsFalse() {
    XCTAssertFalse(isVersion("2.0.0", lessThan: "1.0.0"))
  }

  func testLessThanMinorReturnsTrue() {
    XCTAssertTrue(isVersion("1.1.0", lessThan: "1.2.0"))
  }

  func testGreaterThanMinorReturnsFalse() {
    XCTAssertFalse(isVersion("1.2.0", lessThan: "1.1.0"))
  }

  func testLessThanPatchReturnsTrue() {
    XCTAssertTrue(isVersion("1.0.1", lessThan: "1.0.2"))
  }

  func testGreaterThanPatchReturnsFalse() {
    XCTAssertFalse(isVersion("1.0.2", lessThan: "1.0.1"))
  }

  func testMissingPatchTreatedAsZero() {
    XCTAssertFalse(isVersion("1.0", lessThan: "1.0.0"))
    XCTAssertTrue(isVersion("1.0", lessThan: "1.0.1"))
  }

  func testMissingPatchOnRequiredTreatedAsZero() {
    XCTAssertFalse(isVersion("1.0.0", lessThan: "1.0"))
    XCTAssertFalse(isVersion("1.0.1", lessThan: "1.0"))
  }

  func testTwoComponentVersions() {
    XCTAssertTrue(isVersion("1.0", lessThan: "1.1"))
    XCTAssertFalse(isVersion("1.1", lessThan: "1.0"))
  }
}
