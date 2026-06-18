import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct CongratsActionTests {
  @Test func codableRoundTrips() throws {
    let action = CongratsAction(
      giveawayId: "g1", stationId: "s1", state: .uploaded(audioBlockId: "ab1"),
      startedAt: Date(timeIntervalSince1970: 1_000_000))
    let data = try JSONEncoder().encode(action)
    let back = try JSONDecoder().decode(CongratsAction.self, from: data)
    expectNoDifference(back, action)
  }

  @Test func audioBlockIdOnlyPresentWhenUploaded() {
    var action = CongratsAction.mock
    #expect(action.audioBlockId == nil)
    action.state = .uploaded(audioBlockId: "ab1")
    #expect(action.audioBlockId == "ab1")
    action.state = .submitted
    #expect(action.audioBlockId == nil)
  }

  @Test func isTerminalForSubmittedAndAlreadyClosed() {
    var action = CongratsAction.mock
    #expect(!action.isTerminal)
    action.state = .uploaded(audioBlockId: "ab1")
    #expect(!action.isTerminal)
    action.state = .submitted
    #expect(action.isTerminal)
    action.state = .alreadyClosed
    #expect(action.isTerminal)
  }
}
