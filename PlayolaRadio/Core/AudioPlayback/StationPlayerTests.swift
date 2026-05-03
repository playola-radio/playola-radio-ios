//
//  StationPlayerTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationPlayerTests {

  // MARK: - seekNext Tests

  @Test
  func testSeekNextPlaysNextStation() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[1].id)
  }

  @Test
  func testSeekNextWrapsAroundFromLastToFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[2])

    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithNoCurrentStationPlaysFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithEmptyStationListDoesNothing() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation == nil)
  }

  // MARK: - seekPrevious Tests

  @Test
  func testSeekPreviousPlaysPreviousStation() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[1])

    stationPlayer.seekPrevious()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekPreviousWrapsAroundFromFirstToLast() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekPrevious()

    #expect(stationPlayer.currentStation?.id == stations[2].id)
  }

  @Test
  func testSeekPreviousWithNoCurrentStationPlaysFirst() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    stationPlayer.seekPrevious()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  // MARK: - Station Filtering Tests

  @Test
  func testSeekOnlyUsesArtistListStations() {
    @Shared(.stationLists) var stationLists = makeArtistAndFmLists()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let artistList = stationLists.first { $0.id == StationList.KnownIDs.artistList.rawValue }!
    let artistStations = artistList.stations

    stationPlayer.play(station: artistStations[0])
    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == artistStations[1].id)
  }

  @Test
  func testSeekSkipsInactiveStations() {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekSkipsComingSoonStationsWhenSecretsDisabled() {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekIncludesComingSoonStationsWhenSecretsEnabled() {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    stationPlayer.play(station: allStations[0])
    stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == allStations[1].id)
  }

  // MARK: - seekableStations Tests

  @Test
  func testSeekableStationsReturnsStationsFromArtistList() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.count == 3)
    #expect(seekable[0].id == "station1")
    #expect(seekable[1].id == "station2")
    #expect(seekable[2].id == "station3")
  }

  @Test
  func testSeekableStationsReturnsEmptyWhenNoArtistList() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.isEmpty)
  }

  @Test
  func testSeekableStationsFiltersInactiveStations() {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.count == 2)
    #expect(seekable[0].id == "station1")
    #expect(seekable[1].id == "station3")
  }

  @Test
  func testSeekableStationsAccessesSharedState() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    // Verify stationPlayer can see the shared state
    #expect(stationPlayer.stationLists.count == 1, "StationPlayer should see 1 station list")
    #expect(
      stationPlayer.stationLists.first?.slug == "artist-list",
      "StationPlayer should see artist-list slug")
  }

  // MARK: - isSeeking Flag Tests

  @Test
  func testIsSeekingIsFalseByDefault() {
    let stationPlayer = StationPlayer()
    #expect(!stationPlayer.isSeeking)
  }

  @Test
  func testIsSeekingIsFalseAfterSeekNextCompletes() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[0])

    stationPlayer.seekNext()

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseAfterSeekPreviousCompletes() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    stationPlayer.play(station: stations[1])

    stationPlayer.seekPrevious()

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseWhenSeekHasNoStations() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    stationPlayer.seekNext()

    #expect(!stationPlayer.isSeeking, "isSeeking should remain false when no stations")
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
