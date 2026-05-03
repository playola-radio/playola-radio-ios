import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct LikedSongsPageTests {
  @Test
  func testGroupedLikedSongsEmptyWhenNoLikes() {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = LikedSongsPageModel()

      #expect(model.groupedLikedSongs.isEmpty)
    }
  }

  @Test
  func testGroupedLikedSongsGroupsBySectionTitle() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")

    withDependencies {
      $0.date.now = Date()
      let likesManager = LikesManager()
      likesManager.like(audioBlock1)
      likesManager.like(audioBlock2)
      $0.likesManager = likesManager
    } operation: {
      let model = LikedSongsPageModel()

      #expect(!model.groupedLikedSongs.isEmpty)
      #expect(model.groupedLikedSongs.first?.1.count == 2)
    }
  }

  @Test
  func testFormatTimestamp() {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = LikedSongsPageModel()
      let testDate = Date()

      let result = model.formatTimestamp(for: testDate)

      #expect(!result.isEmpty)
      #expect(result.contains("at"))
    }
  }

  @Test
  func testRemoveSong() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    withDependencies {
      $0.date.now = Date()
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = LikedSongsPageModel()

      #expect(!model.groupedLikedSongs.isEmpty)

      model.removeSongTapped(audioBlock)

      #expect(model.groupedLikedSongs.isEmpty)
    }
  }
}
