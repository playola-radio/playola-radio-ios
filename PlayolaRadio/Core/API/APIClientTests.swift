//
//  APIClientTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/31/25.
//

import XCTest

@testable import PlayolaRadio

@MainActor
final class APIClientTests: XCTestCase {

  // MARK: - URL Encoding Tests

  func testS3KeyWithSlashIsProperlyEncodedForURLPath() {
    let s3Key = "station123/mock-uuid.m4a"

    // Using urlQueryAllowed does NOT encode "/" - this is the bug
    let badEncoding = s3Key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    XCTAssertEqual(badEncoding, "station123/mock-uuid.m4a", "urlQueryAllowed doesn't encode slash")

    // The correct encoding should encode "/" as %2F
    var allowedCharacters = CharacterSet.urlPathAllowed
    allowedCharacters.remove("/")
    let goodEncoding = s3Key.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    XCTAssertEqual(goodEncoding, "station123%2Fmock-uuid.m4a", "Slash should be encoded as %2F")
  }
}
