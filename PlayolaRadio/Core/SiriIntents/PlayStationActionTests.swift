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
      $0.stationPlayer = StationPlayer()
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
      $0.stationPlayer = StationPlayer()
    } operation: {
      await PlayStationAction().run(stationID: "does-not-exist")
    }
    #expect(outcome == .notFound)
  }

  @Test
  func testLoggedInValidStationPlaysAndReturnsPlaying() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.stationLists) var stationLists = makeStationLists()
    let player = StationPlayer()
    let outcome = await withDependencies {
      $0.stationPlayer = player
    } operation: {
      await PlayStationAction().run(stationID: "koke-fm-id")
    }
    #expect(outcome == .playing(stationName: "KOKE FM"))
    #expect(player.currentStation?.id == "koke-fm-id")
  }
}
