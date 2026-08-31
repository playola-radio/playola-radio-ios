//
//  BreakersLibraryPageTests.swift
//  PlayolaRadio
//

import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct BreakersLibraryPageTests {

  private let testStationId = "station-abc"

  private func makeModel(
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> BreakersLibraryPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    return await withDependencies {
      configure(&$0)
    } operation: {
      let model = BreakersLibraryPageModel(stationId: testStationId)
      await model.viewAppeared()
      return model
    }
  }

  @Test func filtersOutSongCategoriesAndSortsByName() async {
    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Zebra Sounders", audioBlockType: .commercialblock,
        audioBlocks: [.mockWith(id: "z")]),
      .mockWith(
        id: "2", name: "All Songs", audioBlockType: .song, audioBlocks: [.mockWith(id: "s")]),
      .mockWith(
        id: "3", name: "Anthems", audioBlockType: .audioimage,
        audioBlocks: [.mockWith(id: "a")]),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(model.categories.map(\.id), ["3", "1"])
  }

  @Test func filtersOutEmptyCategories() async {
    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Intros", audioBlockType: .audioimage, audioBlocks: [.mockWith(id: "a")]),
      .mockWith(id: "2", name: "Empty Breakers", audioBlockType: .commercialblock, audioBlocks: []),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(model.categories.map(\.id), ["1"])
  }

  @Test func setsErrorAlertWhenFetchFails() async {
    let model = await makeModel {
      $0.api.getStationCategories = { _, _ in throw BreakersLibraryTestError.failed }
    }

    expectNoDifference(
      model.presentedAlert,
      .errorLoadingBreakers(BreakersLibraryTestError.failed.localizedDescription))
  }

  @Test func ignoresCancellationErrorWhenFetchFails() async {
    let model = await makeModel {
      $0.api.getStationCategories = { _, _ in throw CancellationError() }
    }

    #expect(model.presentedAlert == nil)
  }

  @Test func blockCountLabelIsSingularForOneBlock() {
    let model = BreakersLibraryPageModel(stationId: testStationId)
    let category = StationCategory.mockWith(
      audioBlocks: [.mockWith()]
    )

    expectNoDifference(model.blockCountLabel(for: category), "1 clip")
  }

  @Test func blockCountLabelIsPluralForMultipleBlocks() {
    let model = BreakersLibraryPageModel(stationId: testStationId)
    let category = StationCategory.mockWith(
      audioBlocks: [.mockWith(id: "a"), .mockWith(id: "b")]
    )

    expectNoDifference(model.blockCountLabel(for: category), "2 clips")
  }

  @Test func showsEmptyStateWhenNoCategories() async {
    let model = await makeModel { $0.api.getStationCategories = { _, _ in [] } }

    #expect(model.showsEmptyState)
  }

  @Test func hidesEmptyStateWhenCategoriesPresent() async {
    let categories: [StationCategory] = [
      .mockWith(
        id: "1", name: "Anthems", audioBlockType: .audioimage, audioBlocks: [.mockWith(id: "a")])
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    #expect(!model.showsEmptyState)
  }

  @Test func categoryRowTappedPushesDetailPage() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = BreakersLibraryPageModel(stationId: testStationId)
    let category = StationCategory.mockWith(id: "1", name: "Intros")

    model.categoryRowTapped(category)

    guard case .breakerCategoryDetailPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a breakerCategoryDetailPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.category.id, category.id)
  }
}

private enum BreakersLibraryTestError: Error {
  case failed
}
