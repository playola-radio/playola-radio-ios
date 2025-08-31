import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class LikedSongsPageModel: ViewModel {
  @ObservationIgnored @Dependency(\.likesManager) var likesManager: LikesManager

  var presentedSongActionSheet: SongActionSheet? = nil

  var groupedLikedSongs: [(String, [(AudioBlock, Date)])] {
    let songsWithTimestamps = likesManager.allLikedAudioBlocksWithTimestamps

    let grouped = Dictionary(grouping: songsWithTimestamps) { audioBlockWithTimestamp in
      let (_, likedDate) = audioBlockWithTimestamp
      return formatSectionTitle(for: likedDate)
    }

    return
      grouped
      .sorted { first, second in
        let firstDate = parseSectionTitle(first.key)
        let secondDate = parseSectionTitle(second.key)
        return firstDate > secondDate
      }
      .map { (key, value) in
        let sortedSongs = value.sorted { first, second in
          let (_, firstDate) = first
          let (_, secondDate) = second
          return firstDate > secondDate
        }
        return (key, sortedSongs)
      }
  }

  func menuButtonTapped(for audioBlock: AudioBlock, likedDate: Date) {
    presentedSongActionSheet = SongActionSheet(audioBlock: audioBlock, likedDate: likedDate)
  }

  func removeSong(_ audioBlock: AudioBlock) {
    likesManager.unlike(audioBlock)
  }

  private func formatSectionTitle(for date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
      return "Last Week"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMMM yyyy"
      return formatter.string(from: date)
    }
  }

  private func parseSectionTitle(_ title: String) -> Date {
    if title == "Last Week" {
      return Date()
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMMM yyyy"
      return formatter.date(from: title) ?? Date.distantPast
    }
  }

  func formatTimestamp(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
    return formatter.string(from: date)
  }
}

struct SongActionSheet: Identifiable {
  let id = UUID()
  let audioBlock: AudioBlock
  let likedDate: Date
}
