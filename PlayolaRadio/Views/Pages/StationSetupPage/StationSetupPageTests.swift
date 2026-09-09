//
//  StationSetupPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationSetupPageTests {

  // MARK: - Test Helpers

  private nonisolated static func testStation(name: String = "Southern Lines Radio")
    -> PlayolaPlayer.Station
  {
    PlayolaPlayer.Station(
      id: "station-abc",
      name: name,
      curatorName: "Curator",
      imageUrl: String?.none,
      description: "",
      active: true,
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0))
  }

  private nonisolated static func factor(
    current: Int, required: Int, progress: Double, weight: Double
  ) -> StationSetupProgress.Factor {
    StationSetupProgress.Factor(
      current: current, required: required, progress: progress, weight: weight)
  }

  private nonisolated static func setupProgress(
    displayPercentage: Int = 50,
    progress: Double = 0.5,
    sourceTapes: StationSetupProgress.Factor? = nil,
    welcome: StationSetupProgress.Factor? = nil,
    songs: StationSetupProgress.Factor? = nil,
    breakers: StationSetupProgress.Factor? = nil
  ) -> StationSetupProgress {
    StationSetupProgress(
      stationId: "station-abc",
      progress: progress,
      displayPercentage: displayPercentage,
      factors: StationSetupProgress.Factors(
        sourceTapes: sourceTapes ?? factor(current: 3, required: 3, progress: 1, weight: 0.25),
        welcome: welcome ?? factor(current: 1, required: 1, progress: 1, weight: 0.15),
        songs: songs ?? factor(current: 5, required: 10, progress: 0.5, weight: 0.15),
        breakers: breakers ?? factor(current: 2, required: 10, progress: 0.2, weight: 0.20)))
  }

  private nonisolated static func category(
    id: String, name: String, minimum: Int, count: Int, sortOrder: Int,
    type: AudioBlockCategoryType = .song
  ) -> StationCategoryProgress {
    StationCategoryProgress(
      id: id, name: name, audioBlockType: type, minimumCount: minimum, burnoutCount: nil,
      audioBlockCount: count, sortOrder: sortOrder)
  }

  private nonisolated static let emptyCategoryResponse = StationCategoryProgressResponse(
    usesCategoryProgress: false, readiness: nil, categories: [])

  private func makeModel(
    stationName: String = "Southern Lines Radio",
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> StationSetupPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    return await withDependencies {
      $0.api.getStationSetupProgress = { _, _ in Self.setupProgress() }
      $0.api.getDraftStationCategoryProgress = { _, _ in Self.emptyCategoryResponse }
      configure(&$0)
    } operation: {
      let model = StationSetupPageModel(station: Self.testStation(name: stationName))
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Ring

  @Test func ringUsesServerDisplayPercentageDirectly() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(displayPercentage: 47, progress: 0.47)
      }
    }

    expectNoDifference(model.ringPercentLabel, "47%")
    expectNoDifference(model.ringProgress, 0.47)
  }

  @Test func ringDefaultsToZeroBeforeLoad() {
    let model = StationSetupPageModel(station: Self.testStation())

    expectNoDifference(model.ringPercentLabel, "0%")
    expectNoDifference(model.ringProgress, 0)
  }

  // MARK: - Tagline

  @Test func taglineComposesStationNameClientSide() async {
    let model = await makeModel(stationName: "Southern Lines Radio")

    expectNoDifference(model.tagline, "Southern Lines Radio is taking shape")
  }

  // MARK: - Component Rows

  @Test func completeFactorUsesGreenTint() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          sourceTapes: Self.factor(current: 3, required: 3, progress: 1, weight: 0.25))
      }
    }

    expectNoDifference(model.componentRows[0].tint, Color(hex: "#34C759"))
  }

  @Test func incompleteFactorAboveHalfUsesAmberTint() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          welcome: Self.factor(current: 0, required: 1, progress: 0.6, weight: 0.15))
      }
    }

    expectNoDifference(model.componentRows[1].tint, Color(hex: "#FFC107"))
  }

  @Test func incompleteFactorBelowHalfUsesRedTint() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          songs: Self.factor(current: 1, required: 10, progress: 0.3, weight: 0.15))
      }
    }

    expectNoDifference(model.componentRows[2].tint, .playolaRed)
  }

  @Test func welcomeValueTextShowsReadyWhenComplete() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(welcome: Self.factor(current: 1, required: 1, progress: 1, weight: 0.15))
      }
    }

    expectNoDifference(model.componentRows[1].valueText, "Ready")
  }

  @Test func welcomeValueTextShowsNotReadyWhenIncomplete() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(welcome: Self.factor(current: 0, required: 1, progress: 0, weight: 0.15))
      }
    }

    expectNoDifference(model.componentRows[1].valueText, "Not ready")
  }

  @Test func nonWelcomeValueTextShowsCurrentOfRequired() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          songs: Self.factor(current: 4, required: 12, progress: 0.33, weight: 0.15))
      }
    }

    expectNoDifference(model.componentRows[2].valueText, "4 of 12")
  }

  @Test func componentsCompletionLabelCountsCompleteFactors() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          sourceTapes: Self.factor(current: 3, required: 3, progress: 1, weight: 0.25),
          welcome: Self.factor(current: 0, required: 1, progress: 0, weight: 0.15),
          songs: Self.factor(current: 1, required: 10, progress: 0.1, weight: 0.15),
          breakers: Self.factor(current: 0, required: 10, progress: 0, weight: 0.20))
      }
    }

    expectNoDifference(model.componentsCompletionLabel, "1 OF 4 COMPLETE")
  }

  @Test func componentsCompletionLabelDefaultsToZeroBeforeLoad() {
    let model = StationSetupPageModel(station: Self.testStation())

    expectNoDifference(model.componentsCompletionLabel, "0 OF 4 COMPLETE")
    expectNoDifference(model.componentRows.isEmpty, true)
  }

  @Test func weightCaptionReflectsServerWeight() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        Self.setupProgress(
          songs: Self.factor(current: 5, required: 10, progress: 0.5, weight: 0.15),
          breakers: Self.factor(current: 2, required: 10, progress: 0.2, weight: 0.20))
      }
    }

    expectNoDifference(model.componentRows[2].weightCaption, "15% of setup")
    expectNoDifference(model.componentRows[3].weightCaption, "20% of setup")
  }

  // MARK: - Category Rows

  @Test func categoryRowsSortBySortOrderAscending() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 0.5,
          categories: [
            Self.category(id: "c2", name: "Breakers", minimum: 5, count: 5, sortOrder: 2),
            Self.category(id: "c1", name: "Fan Spotlights", minimum: 5, count: 1, sortOrder: 1),
          ])
      }
    }

    expectNoDifference(model.categoryRows.map(\.name), ["Fan Spotlights", "Breakers"])
  }

  @Test func completeCategoryUsesCheckmarkAndGreenTint() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 1,
          categories: [
            Self.category(id: "c1", name: "Fan Spotlights", minimum: 5, count: 5, sortOrder: 0)
          ])
      }
    }

    let row = model.categoryRows[0]
    expectNoDifference(row.iconSystemName, "checkmark.circle")
    expectNoDifference(row.tint, Color(hex: "#34C759"))
    expectNoDifference(row.countText, "5 / 5")
  }

  @Test func overDeliveredCategoryStillCountsAsComplete() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 1,
          categories: [
            Self.category(id: "c1", name: "Fan Spotlights", minimum: 5, count: 9, sortOrder: 0)
          ])
      }
    }

    let row = model.categoryRows[0]
    expectNoDifference(row.iconSystemName, "checkmark.circle")
    expectNoDifference(row.tint, Color(hex: "#34C759"))
    expectNoDifference(row.countText, "9 / 5")
  }

  @Test func incompleteCategoryBelowHalfUsesDashedIconAndRedTint() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 0.4,
          categories: [
            Self.category(id: "c1", name: "Fan Spotlights", minimum: 5, count: 2, sortOrder: 0)
          ])
      }
    }

    let row = model.categoryRows[0]
    expectNoDifference(row.iconSystemName, "circle.dashed")
    expectNoDifference(row.tint, .playolaRed)
    expectNoDifference(row.countText, "2 / 5")
  }

  @Test func incompleteCategoryAtOrAboveHalfUsesAmberTint() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 0.6,
          categories: [
            Self.category(id: "c1", name: "Fan Spotlights", minimum: 5, count: 3, sortOrder: 0)
          ])
      }
    }

    let row = model.categoryRows[0]
    expectNoDifference(row.iconSystemName, "circle.dashed")
    expectNoDifference(row.tint, Color(hex: "#FFC107"))
    expectNoDifference(row.countText, "3 / 5")
  }

  @Test func categoryCountLabelReflectsCategoryCount() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in
        StationCategoryProgressResponse(
          usesCategoryProgress: true, readiness: 0.5,
          categories: [
            Self.category(id: "c1", name: "A", minimum: 5, count: 1, sortOrder: 0),
            Self.category(id: "c2", name: "B", minimum: 5, count: 1, sortOrder: 1),
            Self.category(id: "c3", name: "C", minimum: 5, count: 1, sortOrder: 2),
          ])
      }
    }

    expectNoDifference(model.categoryCountLabel, "3 CATEGORIES")
  }

  @Test func emptyCategoriesProducesZeroCountAndNoRows() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in Self.emptyCategoryResponse }
    }

    expectNoDifference(model.categoryCountLabel, "0 CATEGORIES")
    expectNoDifference(model.categoryRows.isEmpty, true)
  }

  // MARK: - Error Handling

  @Test func setupProgressErrorPresentsAlertAndStaysNeutral() async {
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in throw TestError.networkError }
    }

    expectNoDifference(model.presentedAlert != nil, true)
    expectNoDifference(model.ringPercentLabel, "0%")
    expectNoDifference(model.componentRows.isEmpty, true)
  }

  @Test func categoryProgressErrorPresentsAlertAndStaysNeutral() async {
    let model = await makeModel {
      $0.api.getDraftStationCategoryProgress = { _, _ in throw TestError.networkError }
    }

    expectNoDifference(model.presentedAlert != nil, true)
    expectNoDifference(model.categoryRows.isEmpty, true)
    expectNoDifference(model.categoryCountLabel, "0 CATEGORIES")
  }

  @Test func skipsLoadWhenNoAuthToken() async {
    @Shared(.auth) var auth = Auth()
    let captured = LockIsolated(false)

    let model = await withDependencies {
      $0.api.getStationSetupProgress = { _, _ in
        captured.setValue(true)
        return Self.setupProgress()
      }
    } operation: {
      let model = StationSetupPageModel(station: Self.testStation())
      await model.viewAppeared()
      return model
    }

    expectNoDifference(captured.value, false)
    expectNoDifference(model.ringPercentLabel, "0%")
  }

  // MARK: - Reload Staleness

  @Test func reloadFailureClearsStaleProgress() async {
    let shouldFail = LockIsolated(false)
    let model = await makeModel {
      $0.api.getStationSetupProgress = { _, _ in
        if shouldFail.value { throw TestError.networkError }
        return Self.setupProgress(displayPercentage: 88, progress: 0.88)
      }
    }

    expectNoDifference(model.ringPercentLabel, "88%")

    shouldFail.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.ringPercentLabel, "0%")
    expectNoDifference(model.presentedAlert != nil, true)
  }

  @Test func staleInFlightLoadDoesNotClobberNewerLoad() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let callCount = LockIsolated(0)
    let releaseFirst = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let firstStarted = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.getStationSetupProgress = { _, _ in
        let isFirst = callCount.withValue { count in
          count += 1
          return count == 1
        }
        if isFirst {
          firstStarted.continuation.yield()
          await withCheckedContinuation { releaseFirst.setValue($0) }
          return Self.setupProgress(displayPercentage: 11, progress: 0.11)
        }
        return Self.setupProgress(displayPercentage: 99, progress: 0.99)
      }
      $0.api.getDraftStationCategoryProgress = { _, _ in Self.emptyCategoryResponse }
    } operation: {
      StationSetupPageModel(station: Self.testStation())
    }

    let taskA = Task { await model.viewAppeared() }
    var iterator = firstStarted.stream.makeAsyncIterator()
    await iterator.next()

    await model.viewAppeared()
    expectNoDifference(model.ringPercentLabel, "99%")

    releaseFirst.value?.resume()
    await taskA.value

    expectNoDifference(model.ringPercentLabel, "99%")
  }
}

private enum TestError: Error {
  case networkError
}
