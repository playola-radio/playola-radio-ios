//
//  APIClientRecordedShowsTests.swift
//  PlayolaRadioTests
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct APIClientRecordedShowsTests {
  private func encodedObject(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - Error mapping

  @Test func lockedErrorMapsToRecordedShowLocked() {
    let body = Data(
      """
      { "error": { "message": "This show airs soon and can't be changed.",
        "data": { "code": "AIRING_EDIT_LOCKED" } } }
      """.utf8)

    let error = recordedShowAPIError(data: body)

    guard case .recordedShowLocked(let message) = error else {
      Issue.record("Expected .recordedShowLocked, got \(error)")
      return
    }
    expectNoDifference(message, "This show airs soon and can't be changed.")
    expectNoDifference(error.errorDescription, "This show airs soon and can't be changed.")
  }

  @Test func overlapErrorMapsToServerErrorWithMessage() {
    let body = Data(
      """
      { "error": { "message": "This overlaps Fall Favorites, which airs 7:00–7:38 PM.",
        "data": { "code": "AIRING_OVERLAP" } } }
      """.utf8)

    let error = recordedShowAPIError(data: body)

    guard case .serverError(let message) = error else {
      Issue.record("Expected .serverError, got \(error)")
      return
    }
    expectNoDifference(message, "This overlaps Fall Favorites, which airs 7:00–7:38 PM.")
  }

  @Test func unknownErrorCodeKeepsServerMessage() {
    let body = Data(
      """
      { "error": { "message": "Something new.", "data": { "code": "SOMETHING_ELSE" } } }
      """.utf8)

    let error = recordedShowAPIError(data: body)

    guard case .serverError(let message) = error else {
      Issue.record("Expected .serverError, got \(error)")
      return
    }
    expectNoDifference(message, "Something new.")
  }

  @Test func messageOnlyRefusalMapsToServerError() {
    let body = Data(
      """
      { "error": { "message": "Unschedule this show before removing its last audio." } }
      """.utf8)

    let error = recordedShowAPIError(data: body)

    guard case .serverError(let message) = error else {
      Issue.record("Expected .serverError, got \(error)")
      return
    }
    expectNoDifference(message, "Unschedule this show before removing its last audio.")
  }

  @Test func unparseableErrorBodyGetsGenericMessage() {
    let error = recordedShowAPIError(data: Data("<html>".utf8))

    guard case .serverError(let message) = error else {
      Issue.record("Expected .serverError, got \(error)")
      return
    }
    expectNoDifference(message, "Something went wrong. Please try again.")
  }

  // MARK: - Request bodies

  @Test func episodeUpdateRenameOmitsShowId() throws {
    let object = try encodedObject(CuratorEpisodeUpdate(title: "New title", series: nil))

    expectNoDifference(object["title"] as? String, "New title")
    #expect(object["showId"] == nil)
  }

  @Test func seriesChangeJoinEncodesShowId() throws {
    let object = try encodedObject(CuratorEpisodeUpdate(title: nil, series: .join("series-1")))

    expectNoDifference(object["showId"] as? String, "series-1")
    #expect(object["title"] == nil)
  }

  @Test func seriesChangeMakeStandaloneEncodesExplicitNullShowId() throws {
    let object = try encodedObject(CuratorEpisodeUpdate(title: nil, series: .makeStandalone))

    #expect(object["showId"] is NSNull)
  }

  @Test func updateSeriesOmitsRruleWhenNotChanging() throws {
    let object = try encodedObject(UpdateSeriesParameters(title: "Renamed", rrule: nil))

    expectNoDifference(object["title"] as? String, "Renamed")
    #expect(object["rrule"] == nil)
  }

  @Test func updateSeriesSendsNullToClearRrule() throws {
    let object = try encodedObject(UpdateSeriesParameters(title: "Renamed", rrule: .some(nil)))

    #expect(object["rrule"] is NSNull)
  }

  @Test func updateSeriesSendsRruleWhenChanging() throws {
    let rrule = "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0"
    let object = try encodedObject(UpdateSeriesParameters(title: "Renamed", rrule: .some(rrule)))

    expectNoDifference(object["rrule"] as? String, rrule)
  }

  @Test func createSeriesOmitsRruleWhenNil() throws {
    let object = try encodedObject(
      CreateSeriesParameters(stationId: "station-1", title: "Tuesdays", rrule: nil))

    expectNoDifference(object["stationId"] as? String, "station-1")
    #expect(object["rrule"] == nil)
  }

  @Test func createStandaloneEpisodeBodyIsOneTimeShowWithoutFirstEpisodeTitle() throws {
    let object = try encodedObject(
      CreateStandaloneEpisodeParameters(stationId: "station-1", title: "Pilot"))

    expectNoDifference(object["isOneTime"] as? Bool, true)
    expectNoDifference(object["title"] as? String, "Pilot")
    #expect(object["firstEpisodeTitle"] == nil)
  }

  @Test func addSegmentsSendsAudioBlockIdsAndPosition() throws {
    let object = try encodedObject(
      AddEpisodeSegmentsParameters(audioBlockIds: ["a", "b"], position: 3))

    expectNoDifference(object["audioBlockIds"] as? [String], ["a", "b"])
    expectNoDifference(object["position"] as? Int, 3)
    #expect(object["audioBlockId"] == nil)
  }

  @Test func scheduleBodyCarriesEpisodeStationAndIsoAirtime() throws {
    let airtime = Date(timeIntervalSince1970: 1_794_362_400)
    let object = try encodedObject(
      ScheduleEpisodeParameters(episodeId: "e1", stationId: "s1", airtime: airtime))

    expectNoDifference(object["episodeId"] as? String, "e1")
    expectNoDifference(object["stationId"] as? String, "s1")
    expectNoDifference(object["airtime"] as? String, "2026-11-11T02:00:00Z")
  }
}
