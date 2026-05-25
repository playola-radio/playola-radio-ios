//
//  PresetTests.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct PresetTests {

  // MARK: - Decode

  @Test
  func testPresetDecodesPlayolaStationPayload() throws {
    let json = """
      {
        "id": "8e2c4f1a-9b3d-4e6c-9f1a-2b8e4c6d8f10",
        "userId": "6d00ed09-b85d-425b-a68a-a3f82891dcc5",
        "stationId": "f4a1b2c3-d4e5-6789-abcd-ef0123456789",
        "urlStationId": null,
        "position": 0,
        "createdAt": "2026-05-25T14:00:00.000Z",
        "updatedAt": "2026-05-25T14:00:00.000Z",
        "station": {
          "id": "f4a1b2c3-d4e5-6789-abcd-ef0123456789",
          "name": "Spark Radio",
          "slug": "spark-radio",
          "imageUrl": "https://playola.fm/stations/spark-radio.jpg"
        },
        "urlStation": null
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoderWithIsoFull()
    let preset = try decoder.decode(Preset.self, from: json)

    #expect(preset.id == "8e2c4f1a-9b3d-4e6c-9f1a-2b8e4c6d8f10")
    #expect(preset.stationId == "f4a1b2c3-d4e5-6789-abcd-ef0123456789")
    #expect(preset.urlStationId == nil)
    #expect(preset.position == 0)
    #expect(preset.station?.name == "Spark Radio")
    #expect(preset.station?.slug == "spark-radio")
    #expect(preset.urlStation == nil)
  }

  @Test
  func testPresetDecodesUrlStationPayload() throws {
    let json = """
      {
        "id": "1c5d8e9a-2b3c-4d5e-9f0a-1b2c3d4e5f60",
        "userId": "6d00ed09-b85d-425b-a68a-a3f82891dcc5",
        "stationId": null,
        "urlStationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "position": 1,
        "createdAt": "2026-05-25T14:01:00.000Z",
        "updatedAt": "2026-05-25T14:01:00.000Z",
        "station": null,
        "urlStation": {
          "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
          "name": "KUTX 98.9",
          "url": "https://kut-hd2.streamguys1.com/kut-hd2.aac",
          "imageUrl": "https://playola.fm/url-stations/kutx.jpg"
        }
      }
      """.data(using: .utf8)!

    let decoder = JSONDecoderWithIsoFull()
    let preset = try decoder.decode(Preset.self, from: json)

    #expect(preset.id == "1c5d8e9a-2b3c-4d5e-9f0a-1b2c3d4e5f60")
    #expect(preset.stationId == nil)
    #expect(preset.urlStationId == "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
    #expect(preset.position == 1)
    #expect(preset.station == nil)
    #expect(preset.urlStation?.name == "KUTX 98.9")
    #expect(preset.urlStation?.url == "https://kut-hd2.streamguys1.com/kut-hd2.aac")
  }

  // MARK: - embeddedStationId

  @Test
  func testEmbeddedStationIdReturnsPlayolaStationId() {
    let preset = Preset.mockPlayola(stationId: "playola-id")
    #expect(preset.embeddedStationId == "playola-id")
  }

  @Test
  func testEmbeddedStationIdReturnsUrlStationId() {
    let preset = Preset.mockUrl(urlStationId: "url-id")
    #expect(preset.embeddedStationId == "url-id")
  }
}
