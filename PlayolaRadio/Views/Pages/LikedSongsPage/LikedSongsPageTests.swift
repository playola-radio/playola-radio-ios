import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class LikedSongsPageTests: XCTestCase {

  override func setUp() async throws {
    try await super.setUp()
    @Shared(.likedAudioBlocks) var likedAudioBlocks: [String: AudioBlock] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []
    $likedAudioBlocks.withLock { $0 = [:] }
    $pendingOperations.withLock { $0 = [] }
  }

  func testGroupedLikedSongs_EmptyWhenNoLikes() async {
    await withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = LikedSongsPageModel()

      XCTAssertTrue(model.groupedLikedSongs.isEmpty)
    }
  }

  func testGroupedLikedSongs_GroupsBySectionTitle() async {
    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")

    await withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock1)
      likesManager.like(audioBlock2)
      $0.likesManager = likesManager
    } operation: {
      let model = LikedSongsPageModel()

      XCTAssertFalse(model.groupedLikedSongs.isEmpty)
      XCTAssertEqual(model.groupedLikedSongs.first?.1.count, 2)
    }
  }

  func testFormatTimestamp() async {
    await withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = LikedSongsPageModel()
      let audioBlock = AudioBlock.mock

      let result = model.formatTimestamp(for: audioBlock)

      XCTAssertFalse(result.isEmpty)
      XCTAssertTrue(result.contains("at"))
    }
  }
}
