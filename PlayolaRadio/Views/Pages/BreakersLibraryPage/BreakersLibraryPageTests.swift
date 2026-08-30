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
      .mockWith(id: "1", name: "Zebra Sounders", audioBlockType: .commercialblock),
      .mockWith(id: "2", name: "All Songs", audioBlockType: .song),
      .mockWith(id: "3", name: "Anthems", audioBlockType: .audioimage),
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    expectNoDifference(model.categories.map(\.id), ["3", "1"])
  }

  @Test func setsErrorAlertWhenFetchFails() async {
    let model = await makeModel {
      $0.api.getStationCategories = { _, _ in throw BreakersLibraryTestError.failed }
    }

    expectNoDifference(model.presentedAlert, .errorLoadingBreakers)
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
      .mockWith(id: "1", name: "Anthems", audioBlockType: .audioimage)
    ]
    let model = await makeModel { $0.api.getStationCategories = { _, _ in categories } }

    #expect(!model.showsEmptyState)
  }
}

private enum BreakersLibraryTestError: Error {
  case failed
}
