//
//  MusicLibraryPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct MusicLibraryPageTests {

  private let testStationId = "station-abc"

  private func makeModel(
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> MusicLibraryPageModel {
    await withDependencies {
      configure(&$0)
    } operation: {
      let model = MusicLibraryPageModel(stationId: testStationId)
      await model.viewAppeared()
      return model
    }
  }

  @Test func keepsOnlySongCategoriesAndSortsByName() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Zydeco", audioBlockType: .song, audioBlocks: [.mockWith(id: "z")]),
      .mockWith(
        id: "2", name: "Station IDs", audioBlockType: .audioimage,
        audioBlocks: [.mockWith(id: "s")]),
      .mockWith(
        id: "3", name: "Americana", audioBlockType: .song, audioBlocks: [.mockWith(id: "a")]),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(model.categories.map(\.id), ["3", "1"])
  }

  @Test func filtersOutEmptyCategories() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Acoustic", audioBlockType: .song, audioBlocks: [.mockWith(id: "a")]),
      .mockWith(id: "2", name: "Empty Songs", audioBlockType: .song, audioBlocks: []),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(model.categories.map(\.id), ["1"])
  }

  @Test func rowsPrependAllSongsWithDedupedCount() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Texas Country", audioBlockType: .song,
        audioBlocks: [.mockWith(id: "a"), .mockWith(id: "b")]),
      .mockWith(
        id: "2", name: "Current Rotation", audioBlockType: .song,
        audioBlocks: [.mockWith(id: "b"), .mockWith(id: "c")]),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(
      model.rows,
      [
        MusicLibraryRow(id: "all-songs", title: "All Songs", songCount: 3, isAllSongs: true),
        MusicLibraryRow(id: "2", title: "Current Rotation", songCount: 2, isAllSongs: false),
        MusicLibraryRow(id: "1", title: "Texas Country", songCount: 2, isAllSongs: false),
      ])
  }

  @Test func rowsAreEmptyWhenNoSongCategories() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = await makeModel { $0.api.getStationCategories = { _, _ in [] } }

    expectNoDifference(model.rows, [])
  }

  @Test func songCountLabelIsSingularForOneSong() {
    let model = MusicLibraryPageModel(stationId: testStationId)
    let row = MusicLibraryRow(id: "1", title: "Acoustic", songCount: 1, isAllSongs: false)

    expectNoDifference(model.songCountLabel(for: row), "1 song")
  }

  @Test func songCountLabelIsPluralForMultipleSongs() {
    let model = MusicLibraryPageModel(stationId: testStationId)
    let row = MusicLibraryRow(id: "1", title: "Acoustic", songCount: 42, isAllSongs: false)

    expectNoDifference(model.songCountLabel(for: row), "42 songs")
  }

  @Test func setsErrorAlertWhenFetchFails() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = await makeModel {
      $0.api.getStationCategories = { _, _ in throw MusicLibraryTestError.failed }
    }

    expectNoDifference(
      model.presentedAlert,
      .errorLoadingSongs(MusicLibraryTestError.failed.localizedDescription))
  }

  @Test func ignoresCancellationErrorWhenFetchFails() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = await makeModel {
      $0.api.getStationCategories = { _, _ in throw CancellationError() }
    }

    #expect(model.presentedAlert == nil)
  }

  // Exercises the `Task.isCancelled` branch specifically: the fetch throws a *non*-cancellation
  // error after the enclosing task is cancelled (mirroring Alamofire, which surfaces
  // AFError.explicitlyCancelled — not Swift's CancellationError — on task cancellation). Only the
  // Task.isCancelled check suppresses the alert here, so removing it would fail this test.
  @Test func ignoresCancellationWhenTaskCancelledMidLoad() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let continuationBox = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let suspended = LockIsolated(false)

    let model = withDependencies {
      $0.api.getStationCategories = { _, _ in
        await withCheckedContinuation { continuation in
          continuationBox.setValue(continuation)
          suspended.setValue(true)
        }
        throw MusicLibraryTestError.failed
      }
    } operation: {
      MusicLibraryPageModel(stationId: testStationId)
    }

    let task = Task { await model.viewAppeared() }
    while !suspended.value { await Task.yield() }
    task.cancel()
    continuationBox.value?.resume()
    await task.value

    #expect(model.presentedAlert == nil)
  }

  @Test func showsEmptyStateWhenNoCategories() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = await makeModel { $0.api.getStationCategories = { _, _ in [] } }

    #expect(model.showsEmptyState)
  }

  @Test func hidesEmptyStateWhenCategoriesPresent() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Acoustic", audioBlockType: .song, audioBlocks: [.mockWith(id: "a")])
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    #expect(!model.showsEmptyState)
  }

  @Test func allSongsRowTappedPushesDetailWithEveryUniqueSong() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Texas Country", audioBlockType: .song,
        audioBlocks: [.mockWith(id: "a"), .mockWith(id: "b")]),
      .mockWith(
        id: "2", name: "Current Rotation", audioBlockType: .song,
        audioBlocks: [.mockWith(id: "b"), .mockWith(id: "c")]),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    model.rowTapped(model.rows[0])

    guard case .musicCategoryDetailPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a musicCategoryDetailPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.title, "All Songs")
    // Songs follow sorted-category order then first-seen: "Current Rotation" (b, c) precedes
    // "Texas Country" (a, b), and the duplicate b is dropped on its second appearance.
    expectNoDifference(pushedModel.songs.map(\.id), ["b", "c", "a"])
  }

  @Test func categoryRowTappedPushesDetailWithCategorySongs() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Texas Country", audioBlockType: .song,
        audioBlocks: [.mockWith(id: "a"), .mockWith(id: "b")])
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    let categoryRow = model.rows[1]
    model.rowTapped(categoryRow)

    guard case .musicCategoryDetailPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a musicCategoryDetailPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.title, "Texas Country")
    expectNoDifference(pushedModel.songs.map(\.id), ["a", "b"])
  }
}

private enum MusicLibraryTestError: Error {
  case failed
}
