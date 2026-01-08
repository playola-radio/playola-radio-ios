//
//  StationPlayerTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class StationPlayerTests: XCTestCase {

  // MARK: - seekNext Tests

  func testSeekNextPlaysNextStation() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[1].id)
  }

  func testSeekNextWrapsAroundFromLastToFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[2])

    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[0].id)
  }

  func testSeekNextWithNoCurrentStationPlaysFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[0].id)
  }

  func testSeekNextWithEmptyStationListDoesNothing() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    stationPlayer.seekNext()

    XCTAssertNil(stationPlayer.currentStation)
  }

  // MARK: - seekPrevious Tests

  func testSeekPreviousPlaysPreviousStation() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[1])

    stationPlayer.seekPrevious()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[0].id)
  }

  func testSeekPreviousWrapsAroundFromFirstToLast() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekPrevious()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[2].id)
  }

  func testSeekPreviousWithNoCurrentStationPlaysFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    stationPlayer.seekPrevious()

    XCTAssertEqual(stationPlayer.currentStation?.id, stations[0].id)
  }

  // MARK: - Station Filtering Tests

  func testSeekOnlyUsesArtistListStations() {
    @Shared(.stationLists) var stationLists = makeArtistAndFmLists()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let artistList = stationLists.first { $0.id == StationList.KnownIDs.artistList.rawValue }!
    let artistStations = artistList.stations

    stationPlayer.play(station: artistStations[0])
    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, artistStations[1].id)
  }

  func testSeekSkipsInactiveStations() {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, allStations[2].id)
  }

  func testSeekSkipsComingSoonStationsWhenSecretsDisabled() {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, allStations[2].id)
  }

  func testSeekIncludesComingSoonStationsWhenSecretsEnabled() {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    XCTAssertEqual(stationPlayer.currentStation?.id, allStations[1].id)
  }

  // MARK: - seekableStations Tests

  func testSeekableStationsReturnsStationsFromArtistList() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    XCTAssertEqual(seekable.count, 3)
    XCTAssertEqual(seekable[0].id, "station1")
    XCTAssertEqual(seekable[1].id, "station2")
    XCTAssertEqual(seekable[2].id, "station3")
  }

  func testSeekableStationsReturnsEmptyWhenNoArtistList() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    XCTAssertTrue(seekable.isEmpty)
  }

  func testSeekableStationsFiltersInactiveStations() {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    XCTAssertEqual(seekable.count, 2)
    XCTAssertEqual(seekable[0].id, "station1")
    XCTAssertEqual(seekable[1].id, "station3")
  }

  func testSeekableStationsAccessesSharedState() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    // Verify stationPlayer can see the shared state
    XCTAssertEqual(stationPlayer.stationLists.count, 1, "StationPlayer should see 1 station list")
    XCTAssertEqual(
      stationPlayer.stationLists.first?.slug, "artist-list",
      "StationPlayer should see artist-list slug")
  }

  // MARK: - isSeeking Flag Tests

  func testIsSeekingIsFalseByDefault() {
    let stationPlayer = StationPlayer()
    XCTAssertFalse(stationPlayer.isSeeking)
  }

  func testIsSeekingIsFalseAfterSeekNextCompletes() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekNext()

    XCTAssertFalse(stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  func testIsSeekingIsFalseAfterSeekPreviousCompletes() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[1])

    stationPlayer.seekPrevious()

    XCTAssertFalse(stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  func testIsSeekingIsFalseWhenSeekHasNoStations() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    stationPlayer.seekNext()

    XCTAssertFalse(stationPlayer.isSeeking, "isSeeking should remain false when no stations")
  }

  // MARK: - Helper Methods

  private func makeArtistListWithThreeStations() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2")
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3")
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeArtistAndFmLists() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "artist1", name: "Artist 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "artist2", name: "Artist 2")
        ),
      ]
    )
    let fmList = StationList(
      id: StationList.KnownIDs.fmStationsList.rawValue,
      name: "FM Stations",
      slug: "fm-list",
      hidden: false,
      sortOrder: 1,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "fm1", name: "FM Station 1")
        )
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList, fmList])
  }

  private func makeArtistListWithInactiveStation() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1", active: true)
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2 (Inactive)", active: false)
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3", active: true)
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeArtistListWithComingSoonStation() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .comingSoon,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2 (Coming Soon)")
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3")
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeUrlStation(id: String, name: String, active: Bool = true) -> UrlStation {
    UrlStation(
      id: id,
      name: name,
      streamUrl: "https://example.com/stream/\(id)",
      imageUrl: "https://example.com/image/\(id).jpg",
      description: "Description for \(name)",
      website: nil,
      location: nil,
      active: active,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
