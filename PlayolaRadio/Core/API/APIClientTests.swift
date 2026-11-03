//
//  APIClientTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/31/25.
//

import CustomDump
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct APIClientTests {

  @Test
  func listeningHistoryDecodesPopulatedSpinsAndSkipsMissingRelations() throws {
    let data = Data(
      """
      {
        "spins": [
          {
            "id": "spin-one", "airtime": "2026-11-01T18:00:00.000Z",
            "station": {"id": "station-one", "name": "Texas Country"},
            "audioBlock": {
              "id": "song-one", "title": "Keep the Wolves Away", "artist": "Uncle Lucius",
              "durationMS": 240000, "endOfMessageMS": 240000,
              "beginningOfOutroMS": 220000, "endOfIntroMS": 10000,
              "lengthOfOutroMS": 20000, "s3Key": "song-one.mp3",
              "s3BucketName": "songs", "type": "song",
              "createdAt": "2026-01-01T00:00:00.000Z",
              "updatedAt": "2026-01-01T00:00:00.000Z"
            }
          },
          {
            "id": "spin-without-song", "airtime": "2026-11-01T17:00:00.000Z",
            "station": {"id": "station-one", "name": "Texas Country"},
            "audioBlock": null
          },
          {
            "id": "spin-without-station", "airtime": "2026-11-01T16:00:00.000Z",
            "station": null,
            "audioBlock": null
          }
        ],
        "pagination": {"limit": 20, "offset": 0, "total": 3, "hasMore": false}
      }
      """.utf8)

    let page = try JSONDecoderWithIsoFull().decode(ListeningHistoryResponse.self, from: data)

    expectNoDifference(page.spins.count, 3)
    expectNoDifference(page.displaySpins.map(\.id), ["spin-one"])
    expectNoDifference(page.displaySpins.first?.station?.name, "Texas Country")
    expectNoDifference(page.displaySpins.first?.audioBlock?.title, "Keep the Wolves Away")
    expectNoDifference(page.pagination.hasMore, false)
  }

  @Test
  func listeningHistoryRejectsMissingPagination() {
    let data = Data("{\"spins\":[]}".utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoderWithIsoFull().decode(ListeningHistoryResponse.self, from: data)
    }
  }

  @Test
  func rewardRedemptionResponseDecodesFulfillmentRequest() throws {
    let request = try decodeRewardRedemptionResponse(
      Data(
        """
        {"id":"r1","status":"awaiting_info","source":"reward","giveawayEventId":null,
         "prize":null,"infoFields":[],"infoAnswers":{}}
        """.utf8))

    expectNoDifference(request.id, "r1")
  }

  @Test
  func malformedRewardRedemptionResponseMapsToConflict() {
    #expect(throws: ClaimAPIError.conflict) {
      try decodeRewardRedemptionResponse(Data("not JSON".utf8))
    }
  }

  // MARK: - URL Encoding Tests

  @Test
  func testS3KeyWithSlashIsProperlyEncodedForURLPath() {
    let s3Key = "station123/mock-uuid.m4a"

    // Using urlQueryAllowed does NOT encode "/" - this is the bug
    let badEncoding = s3Key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    #expect(badEncoding == "station123/mock-uuid.m4a", "urlQueryAllowed doesn't encode slash")

    // The correct encoding should encode "/" as %2F
    var allowedCharacters = CharacterSet.urlPathAllowed
    allowedCharacters.remove("/")
    let goodEncoding = s3Key.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    #expect(goodEncoding == "station123%2Fmock-uuid.m4a", "Slash should be encoded as %2F")
    func testVoicetrackStatusURLEncodesS3KeyWithSlashes() {
      let baseUrl = "https://api.example.com"
      let stationId = "station-123"
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedS3Key =
        s3Key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s3Key
      let url = "\(baseUrl)/v1/stations/\(stationId)/voicetrack-status/\(encodedS3Key)"

      #expect(
        url == "https://api.example.com/v1/stations/station-123/voicetrack-status/"
          + "voicetracks%2Fstation123%2Fabc%2Ddef%2D123%2Em4a"
      )
    }

    func testUrlQueryAllowedDoesNotEncodeSlashes() {
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedWithQueryAllowed =
        s3Key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s3Key

      #expect(
        encodedWithQueryAllowed.contains("/"),
        "urlQueryAllowed does NOT encode slashes - this causes 404 errors when used in URL paths"
      )
    }

    func testAlphanumericsEncodesSlashes() {
      let s3Key = "voicetracks/station123/abc-def-123.m4a"

      let encodedWithAlphanumerics =
        s3Key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s3Key

      #expect(
        !encodedWithAlphanumerics.contains("/"),
        "alphanumerics should encode slashes"
      )
      #expect(
        encodedWithAlphanumerics.contains("%2F"),
        "Slashes should be encoded as %2F"
      )
    }
  }

  // MARK: - Trailing AudioBlock Encoding

  @Test
  func trailingParametersEncodesValueWhenSet() throws {
    let data = try JSONEncoder().encode(
      UpdateTrailingAudioBlockParameters(trailingAudioBlockId: "audio-123"))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["trailingAudioBlockId"] as? String == "audio-123")
  }

  @Test
  func trailingParametersEncodesExplicitNullWhenCleared() throws {
    let data = try JSONEncoder().encode(
      UpdateTrailingAudioBlockParameters(trailingAudioBlockId: nil))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(object?["trailingAudioBlockId"] is NSNull)
  }
}
