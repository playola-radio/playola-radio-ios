//
//  MusicCategoryDetailPageModel.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer

@MainActor
@Observable
class MusicCategoryDetailPageModel: ViewModel {

  // MARK: - Initialization

  init(title: String, songs: [AudioBlock]) {
    self.title = title
    self.songs = songs
    super.init()
  }

  // MARK: - Properties

  let title: String
  let songs: [AudioBlock]

  var navigationTitle: String { title }
  var emptyStateMessage: String { "No songs in this category yet." }

  var showsEmptyState: Bool { songs.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  // MARK: - View Helpers

  func songTitle(for block: AudioBlock) -> String {
    block.title
  }

  func songSubtitle(for block: AudioBlock) -> String {
    block.artist
  }
}
