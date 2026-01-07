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
    func testVoicetrackStatusURLEncodesS3KeyWithSlashes() {
      let baseUrl = "https://api.example.com"
      let stationId = "station-123"
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedS3Key =
        s3Key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s3Key
      let url = "\(baseUrl)/v1/stations/\(stationId)/voicetrack-status/\(encodedS3Key)"

      XCTAssertEqual(
        url,
        "https://api.example.com/v1/stations/station-123/voicetrack-status/"
          + "voicetracks%2Fstation123%2Fabc%2Ddef%2D123%2Em4a"
      )
    }

    func testUrlQueryAllowedDoesNotEncodeSlashes() {
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedWithQueryAllowed =
        s3Key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s3Key

      XCTAssertTrue(
        encodedWithQueryAllowed.contains("/"),
        "urlQueryAllowed does NOT encode slashes - this causes 404 errors when used in URL paths"
      )
    }

    func testAlphanumericsEncodesSlashes() {
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedWithAlphanumerics =
        s3Key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s3Key

      XCTAssertFalse(
        encodedWithAlphanumerics.contains("/"),
        "alphanumerics should encode slashes"
      )
      XCTAssertTrue(
        encodedWithAlphanumerics.contains("%2F"),
        "Slashes should be encoded as %2F"
      )
    }
  }
}
