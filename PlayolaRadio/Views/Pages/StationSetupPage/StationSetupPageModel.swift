//
//  StationSetupPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Observation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class StationSetupPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Types

  struct ComponentRow: Identifiable {
    let id: String
    let iconSystemName: String
    let tint: Color
    let label: String
    let valueText: String
    let progress: Double
    let weightCaption: String
  }

  struct CategoryRow: Identifiable {
    let id: String
    let iconSystemName: String
    let tint: Color
    let name: String
    let countText: String
    let progress: Double
  }

  // MARK: - Initialization

  init(station: PlayolaPlayer.Station) {
    self.station = station
    super.init()
  }

  // MARK: - State

  private let station: PlayolaPlayer.Station
  private var progress: StationSetupProgress?
  private var categoryResponse: StationCategoryProgressResponse?
  /// Bumped once per `viewAppeared`. Each concurrent load captures the value at launch and only
  /// writes back if it still matches, mirroring `ArtistDashboardPageModel`'s stale-guard.
  private var loadGeneration = 0
  var presentedAlert: PlayolaAlert?

  // MARK: - Properties

  var navigationTitle: String { "Dashboard" }
  var inDevelopmentBadgeLabel: String { "IN DEVELOPMENT" }

  var setupEyebrow: String { "STATION SETUP" }
  var ringPercentLabel: String { "\(progress?.displayPercentage ?? 0)%" }
  var ringProgress: Double { Self.clamp01(progress?.progress ?? 0) }
  var ringColor: Color { .playolaRed }
  var tagline: String { "\(station.name) is taking shape" }

  var componentsSectionTitle: String { "STATION COMPONENTS" }
  var componentsCompletionLabel: String { "\(completeComponentCount) OF 4 COMPLETE" }

  var componentRows: [ComponentRow] {
    guard let factors = progress?.factors else { return [] }
    return [
      ComponentRow(
        id: "sourceTapes",
        iconSystemName: "mic.fill",
        tint: tint(for: factors.sourceTapes),
        label: "Source tapes",
        valueText: Self.countValueText(factors.sourceTapes),
        progress: Self.clamp01(factors.sourceTapes.progress),
        weightCaption: Self.weightCaption(factors.sourceTapes.weight)),
      ComponentRow(
        id: "welcome",
        iconSystemName: "speaker.wave.2.fill",
        tint: tint(for: factors.welcome),
        label: "Welcome message",
        valueText: Self.readinessValueText(factors.welcome),
        progress: Self.clamp01(factors.welcome.progress),
        weightCaption: Self.weightCaption(factors.welcome.weight)),
      ComponentRow(
        id: "songs",
        iconSystemName: "music.note",
        tint: tint(for: factors.songs),
        label: "Songs",
        valueText: Self.countValueText(factors.songs),
        progress: Self.clamp01(factors.songs.progress),
        weightCaption: Self.weightCaption(factors.songs.weight)),
      ComponentRow(
        id: "breakers",
        iconSystemName: "dot.radiowaves.left.and.right",
        tint: tint(for: factors.breakers),
        label: "Breakers",
        valueText: Self.countValueText(factors.breakers),
        progress: Self.clamp01(factors.breakers.progress),
        weightCaption: Self.weightCaption(factors.breakers.weight)),
    ]
  }

  var categorySectionTitle: String { "CATEGORY PROGRESS" }
  var categoryCountLabel: String { "\(categoryResponse?.categories.count ?? 0) CATEGORIES" }

  var categoryRows: [CategoryRow] {
    (categoryResponse?.categories ?? [])
      .sorted { $0.sortOrder < $1.sortOrder }
      .map(Self.categoryRow(from:))
  }

  // MARK: - User Actions

  func viewAppeared() async {
    // Bump first so a no-auth reload still invalidates any older in-flight loads before returning.
    loadGeneration += 1
    let generation = loadGeneration
    guard let token = auth.jwt else { return }
    async let setupLoad: Void = loadSetupProgress(
      token: token, stationId: station.id, generation: generation)
    async let categoryLoad: Void = loadCategoryProgress(
      token: token, stationId: station.id, generation: generation)
    _ = await (setupLoad, categoryLoad)
  }

  // MARK: - Private Helpers

  private var completeComponentCount: Int {
    guard let factors = progress?.factors else { return 0 }
    return [factors.sourceTapes, factors.welcome, factors.songs, factors.breakers]
      .filter(Self.isFactorComplete)
      .count
  }

  private func loadSetupProgress(token: String, stationId: String, generation: Int) async {
    do {
      let result = try await api.getStationSetupProgress(token, stationId)
      guard generation == loadGeneration else { return }
      progress = result
    } catch {
      guard !isCancellation(error) else { return }
      guard generation == loadGeneration else { return }
      progress = nil
      presentedAlert = .stationSetupError(error.localizedDescription)
      await analytics.track(
        .apiError(endpoint: "getStationSetupProgress", error: error.localizedDescription))
    }
  }

  private func loadCategoryProgress(token: String, stationId: String, generation: Int) async {
    do {
      let result = try await api.getDraftStationCategoryProgress(token, stationId)
      guard generation == loadGeneration else { return }
      categoryResponse = result
    } catch {
      guard !isCancellation(error) else { return }
      guard generation == loadGeneration else { return }
      categoryResponse = nil
      presentedAlert = .stationSetupError(error.localizedDescription)
      await analytics.track(
        .apiError(endpoint: "getDraftStationCategoryProgress", error: error.localizedDescription))
    }
  }

  /// A cancelled `.task` auto-cancels the in-flight request (Alamofire surfaces
  /// `AFError.explicitlyCancelled`, so `Task.isCancelled` is already set). Treat that as a
  /// non-event: don't clear loaded state, alert, or record an API error for a navigation away.
  private func isCancellation(_ error: any Error) -> Bool {
    Task.isCancelled || error is CancellationError
  }

  private static func clamp01(_ value: Double) -> Double {
    min(1, max(0, value))
  }

  private static func isFactorComplete(_ factor: StationSetupProgress.Factor) -> Bool {
    factor.required == 0 || factor.current >= factor.required
  }

  private func tint(for factor: StationSetupProgress.Factor) -> Color {
    if Self.isFactorComplete(factor) { return Color(hex: "#34C759") }
    if factor.progress >= 0.5 { return Color(hex: "#FFC107") }
    return .playolaRed
  }

  private static func countValueText(_ factor: StationSetupProgress.Factor) -> String {
    "\(factor.current) of \(factor.required)"
  }

  private static func readinessValueText(_ factor: StationSetupProgress.Factor) -> String {
    factor.current >= factor.required ? "Ready" : "Not ready"
  }

  private static func weightCaption(_ weight: Double) -> String {
    "\(Int((weight * 100).rounded()))% of setup"
  }

  private static func categoryRow(from category: StationCategoryProgress) -> CategoryRow {
    let isComplete = category.audioBlockCount >= category.minimumCount
    let fraction =
      category.minimumCount <= 0
      ? 1 : clamp01(Double(category.audioBlockCount) / Double(category.minimumCount))
    let tint: Color =
      isComplete
      ? Color(hex: "#34C759")
      : fraction >= 0.5 ? Color(hex: "#FFC107") : .playolaRed
    return CategoryRow(
      id: category.id,
      iconSystemName: isComplete ? "checkmark.circle" : "circle.dashed",
      tint: tint,
      name: category.name,
      countText: "\(category.audioBlockCount) / \(category.minimumCount)",
      progress: fraction)
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static func stationSetupError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
