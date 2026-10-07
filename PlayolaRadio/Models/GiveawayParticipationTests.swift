import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct GiveawayParticipationTests {
  @Test func codableRoundTrips() throws {
    let participation = GiveawayParticipation(
      id: "g1", stationId: "s1", prizeName: "Tickets", winningNumber: 9,
      tapNumber: 5, status: .tappedStandby,
      tappedAt: Date(timeIntervalSince1970: 1_000_000))
    let data = try JSONEncoder().encode(participation)
    let back = try JSONDecoder().decode(GiveawayParticipation.self, from: data)
    expectNoDifference(back, participation)
  }
}
