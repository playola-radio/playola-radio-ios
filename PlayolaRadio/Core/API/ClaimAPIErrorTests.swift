import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimAPIErrorTests {
  @Test(arguments: [
    (400, ClaimAPIError.invalidAnswers), (403, .notOpen), (404, .notOpen), (409, .conflict),
    (401, .failed), (500, .failed),
  ])
  func testStatusMapping(status: Int, expected: ClaimAPIError) {
    #expect(ClaimAPIError(status: status) == expected)
  }

  @Test func testTransportFailureIsFailed() {
    #expect(ClaimAPIError(status: nil) == .failed)
  }
}
