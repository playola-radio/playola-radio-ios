//
//  MusicLibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class MusicLibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  var categories: IdentifiedArrayOf<StationCategory> = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  var navigationTitle: String { "Music Library" }
  var emptyStateMessage: String { "No songs yet." }

  var showsEmptyState: Bool { !isLoading && categories.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  // MARK: - View Helpers

  var rows: [MusicLibraryRow] {
    guard !categories.isEmpty else { return [] }
    let allSongsRow = MusicLibraryRow(
      id: Self.allSongsRowID,
      title: "All Songs",
      songCount: allSongs.count,
      isAllSongs: true)
    let categoryRows = categories.map { category in
      MusicLibraryRow(
        id: category.id,
        title: category.name,
        songCount: category.audioBlocks.count,
        isAllSongs: false)
    }
    return [allSongsRow] + categoryRows
  }

  func songCountLabel(for row: MusicLibraryRow) -> String {
    row.songCount == 1 ? "1 song" : "\(row.songCount) songs"
  }

  func titleColor(for row: MusicLibraryRow) -> Color {
    row.isAllSongs ? .playolaRed : .white
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadCategories()
  }

  func rowTapped(_ row: MusicLibraryRow) {
    let songs = row.isAllSongs ? allSongs : (categories[id: row.id]?.audioBlocks ?? [])
    navigationCoordinator.push(
      .musicCategoryDetailPage(MusicCategoryDetailPageModel(title: row.title, songs: songs)))
  }

  // MARK: - Private Helpers

  private static let allSongsRowID = "all-songs"

  private var allSongs: [AudioBlock] {
    var seen = Set<String>()
    var result: [AudioBlock] = []
    for category in categories {
      for block in category.audioBlocks where seen.insert(block.id).inserted {
        result.append(block)
      }
    }
    return result
  }

  private func loadCategories() async {
    guard let token = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let all = try await api.getStationCategories(token, stationId)
      categories = IdentifiedArray(
        uniqueElements:
          all
          .filter { $0.isSong }
          .filter { !$0.audioBlocks.isEmpty }
          .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      )
    } catch {
      guard !isCancellation(error) else { return }
      presentedAlert = .errorLoadingSongs(error.localizedDescription)
    }
  }

  /// A cancelled `.task` auto-cancels the in-flight request (Alamofire surfaces
  /// `AFError.explicitlyCancelled`, so `Task.isCancelled` is already set). Treat that as a
  /// non-event: don't alert for a navigation away.
  private func isCancellation(_ error: any Error) -> Bool {
    Task.isCancelled || error is CancellationError
  }
}

struct MusicLibraryRow: Identifiable, Equatable {
  let id: String
  let title: String
  let songCount: Int
  let isAllSongs: Bool
}

extension PlayolaAlert {
  static func errorLoadingSongs(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
