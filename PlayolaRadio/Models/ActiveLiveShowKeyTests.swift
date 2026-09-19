import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@Suite(.freshSharedState)
@MainActor
struct ActiveLiveShowKeyTests {
  @Test func persistsAndClears() {
    @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow? = nil
    #expect(activeLiveShow == nil)

    $activeLiveShow.withLock { $0 = ActiveLiveShow(liveShowId: "show-1", stationId: "station-1") }
    #expect(activeLiveShow?.liveShowId == "show-1")

    $activeLiveShow.withLock { $0 = nil }
    #expect(activeLiveShow == nil)
  }
}

// swiftlint:enable redundant_optional_initialization
