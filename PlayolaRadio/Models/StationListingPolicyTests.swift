import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationListingPolicyTests {
  private func item(_ visibility: StationListItemVisibility, active: Bool) -> APIStationItem {
    APIStationItem(
      sortOrder: 0, visibility: visibility,
      station: Station.mockWith(id: "s1", active: active), urlStation: nil)
  }

  @Test(arguments: [
    // visibility, active, unlocked, listed, playable
    (StationListItemVisibility.visible, true, false, true, true),
    (.visible, true, true, true, true),
    (.visible, false, false, true, false),
    (.comingSoon, true, false, true, false),
    (.comingSoon, true, true, true, true),
    (.comingSoon, false, true, true, false),
    (.hidden, true, false, false, false),
    (.hidden, true, true, true, true),
    (.hidden, false, true, true, false),
    (.unknown, true, true, false, false),
  ])
  func testPolicyTable(
    visibility: StationListItemVisibility, active: Bool, unlocked: Bool, listed: Bool,
    playable: Bool
  ) {
    let subject = item(visibility, active: active)
    #expect(subject.isListed(unlocked: unlocked) == listed)
    #expect(subject.isPlayable(unlocked: unlocked) == playable)
  }

  @Test
  func testItemWithNoStationIsNeitherListedNorPlayable() {
    let empty = APIStationItem(sortOrder: 0, visibility: .visible, station: nil, urlStation: nil)
    #expect(!empty.isListed(unlocked: true))
    #expect(!empty.isPlayable(unlocked: true))
  }

  @Test
  func testMissingVisibilityDecodesAsUnknown() throws {
    let json = """
      {"sortOrder":0,"urlStation":{"id":"u1","name":"U","streamUrl":"https://x",\
      "description":"d","active":true,"createdAt":0,"updatedAt":0}}
      """
    let decoded = try JSONDecoder().decode(APIStationItem.self, from: Data(json.utf8))
    #expect(decoded.visibility == .unknown)
  }

  @Test
  func testPlayableItemLookupRefusesSecretOnLockedDevice() {
    let list = StationList.mockArtistList(items: [item(.hidden, active: true)])
    let lists = IdentifiedArrayOf(uniqueElements: [list])
    #expect(lists.playableItem(stationId: "s1", unlocked: false) == nil)
    #expect(lists.playableItem(stationId: "s1", unlocked: true)?.station?.id == "s1")
    #expect(lists.playableItem(stationId: "missing", unlocked: true) == nil)
  }
}
