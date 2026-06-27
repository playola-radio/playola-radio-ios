import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct PlayStationActionTests {
  private func makeStationLists() -> IdentifiedArrayOf<StationList> {
    let fm = StationList(
      id: "fm_list", name: "FM", slug: "fm_list", hidden: false, sortOrder: 0,
      createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0),
      items: [
        APIStationItem(
          sortOrder: 0, station: nil,
          urlStation: UrlStation(
            id: "koke-fm-id", name: "KOKE FM", streamUrl: "https://example.com/stream",
            imageUrl: "https://example.com/i.png", description: "desc", website: nil,
            location: "Austin, TX", active: true, createdAt: Date(), updatedAt: Date()))
      ]
    )
    return IdentifiedArrayOf(uniqueElements: [fm])
  }

  @Test
  func testLoggedOutReturnsRequiresSignIn() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.stationLists) var stationLists = makeStationLists()
    let outcome = await withDependencies {
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      await PlayStationAction().run(stationID: "koke-fm-id")
    }
    #expect(outcome == .requiresSignIn)
  }

  @Test
  func testUnknownStationReturnsNotFound() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.stationLists) var stationLists = makeStationLists()
    let outcome = await withDependencies {
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      await PlayStationAction().run(stationID: "does-not-exist")
    }
    #expect(outcome == .notFound)
  }

  @Test
  func testLoggedInValidStationPlaysAndReturnsPlaying() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.stationLists) var stationLists = makeStationLists()
    let player = StationPlayerMock()
    let outcome = await withDependencies {
      $0.stationPlayer = player
    } operation: {
      await PlayStationAction().run(stationID: "koke-fm-id")
    }
    #expect(outcome == .playing(stationName: "KOKE FM"))
    #expect(player.callsToPlay.map(\.id) == ["koke-fm-id"])
  }

  // A Playola (artist) station's `stationName` is the internal show name
  // ("Bordertown Radio"), but Siri must confirm the curator-possessive label
  // ("Radney Foster's Station") that the entity/suggestions surfaced. This drives
  // `PlayStationAction().run` end to end so it genuinely guards the action's
  // return value (a regression to `station.stationName` would fail here).
  //
  // Network is avoided by injecting `StationPlayerMock`, which overrides
  // `play(station:)` to record the call instead of reaching the Playola schedule
  // API (`StationPlayer`'s real Playola path calls
  // `PlayolaStationPlayer.shared.play(stationId:)`, whose non-networking init is
  // internal to the PlayolaPlayer package and unreachable from this test target).
  @Test
  func testPlayolaStationUsesCuratorPossessiveLabelInDialog() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let artistList = StationList.mockArtistList(items: [
      APIStationItem(
        sortOrder: 0,
        station: Station.mockWith(
          id: "rf-id", name: "Bordertown Radio", curatorName: "Radney Foster"), urlStation: nil)
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [artistList])
    let player = StationPlayerMock()
    let outcome = await withDependencies {
      $0.stationPlayer = player
    } operation: {
      await PlayStationAction().run(stationID: "rf-id")
    }
    #expect(outcome == .playing(stationName: "Radney Foster's Station"))
    #expect(player.callsToPlay.map(\.id) == ["rf-id"])
  }
}
