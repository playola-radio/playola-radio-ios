import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct CongratsActionTests {
  @Test func codableRoundTripsWithAssociatedValues() throws {
    var action = CongratsAction.mock
    action.state = .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/rec.m4a")
    let data = try JSONEncoder().encode(action)
    let back = try JSONDecoder().decode(CongratsAction.self, from: data)
    expectNoDifference(back, action)
  }

  @Test func associatedValueAccessors() {
    var action = CongratsAction.mock
    action.state = .recorded(localRecordingPath: "/tmp/rec.m4a")
    #expect(action.localRecordingPath == "/tmp/rec.m4a")
    #expect(action.audioBlockId == nil)
    action.state = .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/rec.m4a")
    #expect(action.audioBlockId == "ab1")
    // The local file survives the upload transition so a resumed upload can still play back / clean up.
    #expect(action.localRecordingPath == "/tmp/rec.m4a")
  }

  @Test func terminalStates() {
    var action = CongratsAction.mock
    action.state = .pending
    #expect(!action.isTerminal)
    action.state = .recorded(localRecordingPath: "/x.m4a")
    #expect(!action.isTerminal)
    action.state = .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/rec.m4a")
    #expect(!action.isTerminal)
    action.state = .submitted
    #expect(action.isTerminal)
    action.state = .alreadyClosed
    #expect(action.isTerminal)
    action.state = .skipped
    #expect(action.isTerminal)
  }
}
