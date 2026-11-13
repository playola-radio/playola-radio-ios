//
//  CuratorEpisodeTests.swift
//  PlayolaRadioTests
//

import CustomDump
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct CuratorEpisodeTests {
  private let lockMS = 6 * 60 * 60 * 1000
  private let airtime = Date(timeIntervalSince1970: 1_800_000_000)

  private func makeAiring(
    id: String = "airing-1",
    airtime: Date,
    startTime: Date? = nil,
    endTime: Date? = nil
  ) -> CuratorAiring {
    CuratorAiring(
      id: id, episodeId: "episode-1", stationId: "station-1", airtime: airtime,
      startTime: startTime, endTime: endTime)
  }

  private func makeEpisode(
    durationMS: Int = 30 * 60 * 1000,
    airings: [CuratorAiring] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: "episode-1", showId: "series-1", title: "Fall Favorites", durationMS: durationMS,
      show: nil, segments: [], airings: airings)
  }

  // MARK: - Decoding

  private let episodeJSON = """
    {
      "id": "episode-1", "showId": "series-1", "title": "Fall Favorites", "durationMS": 2280000,
      "show": {
        "id": "series-1", "stationId": "station-1", "title": "Tuesday Evenings",
        "isOneTime": false, "rrule": "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0"
      },
      "segments": [
        {
          "id": "segment-1", "episodeId": "episode-1", "position": 0, "offsetMS": 0,
          "audioBlock": {
            "id": "block-1", "title": "Song", "artist": "Artist", "durationMS": 200000,
            "endOfMessageMS": 198000, "beginningOfOutroMS": 190000, "endOfIntroMS": 5000,
            "lengthOfOutroMS": 8000, "s3Key": "song.mp3", "s3BucketName": "songs",
            "type": "song", "createdAt": "2026-01-01T00:00:00.000Z",
            "updatedAt": "2026-01-01T00:00:00.000Z"
          }
        }
      ],
      "airings": [
        {
          "id": "airing-1", "episodeId": "episode-1", "stationId": "station-1",
          "airtime": "2026-11-11T02:00:00.000Z",
          "startTime": "2026-11-11T02:02:00.000Z", "endTime": "2026-11-11T02:40:00.000Z"
        }
      ]
    }
    """

  @Test func decodesEpisodeWithSegmentsAndAirings() throws {
    let episode = try JSONDecoderWithIsoFull().decode(
      CuratorEpisode.self, from: Data(episodeJSON.utf8))

    expectNoDifference(episode.id, "episode-1")
    expectNoDifference(episode.durationMS, 2_280_000)
    expectNoDifference(
      episode.show,
      CuratorSeries(
        id: "series-1", stationId: "station-1", title: "Tuesday Evenings", isOneTime: false,
        rrule: "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0"))
    expectNoDifference(episode.segments.map(\.id), ["segment-1"])
    expectNoDifference(episode.segments.first?.audioBlock?.id, "block-1")
    expectNoDifference(
      episode.airings,
      [
        CuratorAiring(
          id: "airing-1", episodeId: "episode-1", stationId: "station-1",
          airtime: Date(timeIntervalSince1970: 1_794_362_400),
          startTime: Date(timeIntervalSince1970: 1_794_362_520),
          endTime: Date(timeIntervalSince1970: 1_794_364_800))
      ])
  }

  @Test func decodesRequestOnlySegmentWithoutAudio() throws {
    let json = """
      { "id": "segment-2", "position": 1, "offsetMS": 0 }
      """
    let segment = try JSONDecoderWithIsoFull().decode(
      CuratorEpisodeSegment.self, from: Data(json.utf8))

    #expect(segment.audioBlock == nil)
  }

  @Test func missingSegmentsAndAiringsDecodeAsEmpty() throws {
    let json = """
      { "id": "episode-2", "showId": "series-2", "title": "Bare", "durationMS": 0 }
      """
    let episode = try JSONDecoderWithIsoFull().decode(CuratorEpisode.self, from: Data(json.utf8))

    expectNoDifference(episode.segments, [])
    expectNoDifference(episode.airings, [])
    #expect(episode.show == nil)
  }

  @Test func decodesStationSchedulingSettingsFromFullStationPayload() throws {
    let json = """
      { "id": "station-1", "name": "Texas", "timezone": "America/Chicago",
        "airingEditLockMS": 21600000 }
      """
    let settings = try JSONDecoderWithIsoFull().decode(
      StationSchedulingSettings.self, from: Data(json.utf8))

    expectNoDifference(
      settings, StationSchedulingSettings(timezone: "America/Chicago", airingEditLockMS: 21_600_000)
    )
    expectNoDifference(settings.timeZone.identifier, "America/Chicago")
  }

  @Test func unknownTimeZoneFallsBackToChicago() {
    let settings = StationSchedulingSettings(timezone: "Not/AZone", airingEditLockMS: 1)

    expectNoDifference(settings.timeZone.identifier, "America/Chicago")
  }

  // MARK: - State

  @Test func stateIsDraftWithNoAirings() {
    expectNoDifference(makeEpisode().state(now: airtime, lockMS: lockMS), .draft)
  }

  @Test func stateIsScheduledOneMillisecondBeforeLock() {
    let airing = makeAiring(airtime: airtime)
    let now = airtime.addingTimeInterval(-Double(lockMS) / 1000 - 0.001)

    expectNoDifference(
      makeEpisode(airings: [airing]).state(now: now, lockMS: lockMS), .scheduled(airing))
  }

  @Test func stateIsLockedAtExactlyAirtimeMinusLock() {
    let airing = makeAiring(airtime: airtime)
    let now = airtime.addingTimeInterval(-Double(lockMS) / 1000)

    expectNoDifference(
      makeEpisode(airings: [airing]).state(now: now, lockMS: lockMS), .locked(airing))
  }

  @Test func stateIsLockedWhileOnAir() {
    let airing = makeAiring(
      airtime: airtime, startTime: airtime.addingTimeInterval(60),
      endTime: airtime.addingTimeInterval(1800))
    let now = airtime.addingTimeInterval(600)

    expectNoDifference(
      makeEpisode(airings: [airing]).state(now: now, lockMS: lockMS), .locked(airing))
  }

  @Test func stateIsAiredWhenEveryAiringEnded() {
    let first = makeAiring(
      id: "a1", airtime: airtime, endTime: airtime.addingTimeInterval(1800))
    let second = makeAiring(
      id: "a2", airtime: airtime.addingTimeInterval(86_400),
      endTime: airtime.addingTimeInterval(86_400 + 1800))
    let now = airtime.addingTimeInterval(86_400 + 1800)

    expectNoDifference(
      makeEpisode(airings: [first, second]).state(now: now, lockMS: lockMS), .aired)
  }

  @Test func stateFallsBackToAirtimePlusDurationWhenEndTimeMissing() {
    let airing = makeAiring(airtime: airtime)
    let episode = makeEpisode(durationMS: 600_000, airings: [airing])

    expectNoDifference(
      episode.state(now: airtime.addingTimeInterval(599), lockMS: lockMS), .locked(airing))
    expectNoDifference(episode.state(now: airtime.addingTimeInterval(600), lockMS: lockMS), .aired)
  }

  @Test func stateIsLockedWhenAnotherAiringAlreadyAired() {
    let aired = makeAiring(
      id: "a1", airtime: airtime, endTime: airtime.addingTimeInterval(1800))
    let future = makeAiring(id: "a2", airtime: airtime.addingTimeInterval(30 * 86_400))
    let now = airtime.addingTimeInterval(3600)

    expectNoDifference(
      makeEpisode(airings: [aired, future]).state(now: now, lockMS: lockMS), .locked(future))
  }

  // MARK: - Helpers

  @Test func multiAiringEpisodeIsMultiAiring() {
    let one = makeEpisode(airings: [makeAiring(airtime: airtime)])
    let two = makeEpisode(airings: [
      makeAiring(id: "a1", airtime: airtime), makeAiring(id: "a2", airtime: airtime),
    ])

    #expect(!one.isMultiAiring)
    #expect(two.isMultiAiring)
  }

  @Test func hasAudioFollowsDuration() {
    #expect(!makeEpisode(durationMS: 0).hasAudio)
    #expect(makeEpisode(durationMS: 1).hasAudio)
  }
}
