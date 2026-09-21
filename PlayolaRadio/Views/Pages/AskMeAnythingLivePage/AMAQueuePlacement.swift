import PlayolaPlayer
import SwiftUI

enum AMAPlaylistRowData: Identifiable {
  case scheduled(AMALiveRowData)
  case pending(AMAQueuedRowData)

  var id: String {
    switch self {
    case .scheduled(let row): return "spin:" + row.id
    case .pending(let row): return "pending:" + row.id
    }
  }
  var scheduledRows: [AMALiveRowData] {
    guard case .scheduled(let row) = self else { return [] }
    return [row]
  }
  var pendingRows: [AMAQueuedRowData] {
    guard case .pending(let row) = self else { return [] }
    return [row]
  }
  var canMove: Bool {
    switch self {
    case .scheduled(let row): return row.isEditable
    case .pending(let row): return row.canMove
    }
  }
  var canDelete: Bool {
    switch self {
    case .scheduled(let row): return row.isEditable
    case .pending(let row): return row.canDiscard
    }
  }
}

extension AskMeAnythingLivePageModel {
  var playlistRows: [AMAPlaylistRowData] {
    var rows = liveRows.map(AMAPlaylistRowData.scheduled)
    for pending in pendingRows {
      let predecessors = pendingPredecessors[pending.id]
      let predecessor = predecessors?.first { id in rows.contains { $0.id == id } }
      let desired =
        predecessor.flatMap { id in rows.firstIndex { $0.id == id }.map { $0 + 1 } }
        ?? (predecessors == nil ? rows.count : 0)
      let lockedEnd =
        rows.lastIndex { row in
          row.scheduledRows.contains { !canInsertBefore($0) }
        }.map { $0 + 1 } ?? 0
      let reserveStart =
        rows.firstIndex { row in
          row.scheduledRows.contains { broadcast.showEndDropTargets.contains($0.id) }
        } ?? rows.count
      let index =
        pending.id == outroStagingId
        ? rows.count : max(lockedEnd, min(desired, reserveStart))
      rows.insert(.pending(pending), at: index)
    }
    return rows
  }

  func rememberPendingPosition(_ id: String) {
    pendingPredecessors[id] = playlistRows.map(\.id).reversed()
  }

  func replacePendingPosition(_ item: any StagingItem, previousSpinIds: Set<String>) {
    if let inserted = broadcast.schedule?.spins.first(where: {
      !previousSpinIds.contains($0.id) && $0.audioBlock.id == item.audioBlockId
    }) {
      let localId = "pending:" + item.stagingId
      for id in Array(pendingPredecessors.keys) {
        pendingPredecessors[id] = pendingPredecessors[id]?.map {
          $0 == localId ? "spin:" + inserted.id : $0
        }
      }
    }
    pendingPredecessors[item.stagingId] = nil
  }

  func insertionTarget(for id: String) -> String? {
    let rows = playlistRows
    guard let index = rows.firstIndex(where: { $0.id == "pending:" + id }) else { return nil }
    return rows.dropFirst(index + 1).flatMap(\.scheduledRows).first(where: canInsertBefore)?.id
      ?? broadcast.showEndDropTargets.first
  }

  func deletePlaylistRow(_ row: AMAPlaylistRowData) async {
    switch row {
    case .scheduled(let saved): await deleteLiveRow(saved)
    case .pending(let pending): await discardPendingRow(pending.id)
    }
  }

  func moveLiveRows(from source: IndexSet, to destination: Int) async {
    var rows = playlistRows
    guard canEditLiveQueue, !source.isEmpty,
      source.allSatisfy({ rows.indices.contains($0) && rows[$0].canMove }),
      destination >= 0, destination <= rows.count,
      destination == rows.count || rows[destination].canMove
        || rows[destination].pendingRows.contains(where: { $0.id == outroStagingId }),
      destination != rows.count || outroStagingId == nil
    else { return }
    let source = groupedSource(source, in: rows)
    guard source.allSatisfy({ rows[$0].canMove }) else { return }
    let moving = Set(source.flatMap { rows[$0].scheduledRows.flatMap { $0.spins.map(\.id) } })
    let originalSavedIds = rows.flatMap(\.scheduledRows).map(\.id)
    let originalPositions = pendingPredecessors
    rows.move(fromOffsets: source, toOffset: destination)
    rememberPendingPositions(in: rows)
    if !moving.isEmpty, rows.flatMap(\.scheduledRows).map(\.id) != originalSavedIds {
      let saved = broadcast.upcomingSpins
      let indices = IndexSet(saved.indices.filter { moving.contains(saved[$0].id) })
      let firstMoved = rows.firstIndex { row in
        row.scheduledRows.contains { moving.contains($0.id) }
      }!
      let next = rows.dropFirst(firstMoved).flatMap(\.scheduledRows).flatMap(\.spins)
        .first { !moving.contains($0.id) }
      let target = next.flatMap { next in saved.firstIndex { $0.id == next.id } } ?? saved.count
      isEditingSchedule = true
      let showId = broadcast.liveShowId
      let succeeded = await broadcast.moveSpins(from: indices, to: target)
      if !succeeded, broadcast.liveShowId == showId { pendingPredecessors = originalPositions }
      isEditingSchedule = false
      schedulePlaybackChanged()
    }
    await schedulePendingAudio()
  }

  private func groupedSource(_ source: IndexSet, in rows: [AMAPlaylistRowData]) -> IndexSet {
    let groupIds = Set(
      source.flatMap { rows[$0].scheduledRows.flatMap { $0.spins.compactMap(\.spinGroupId) } })
    return source.union(
      IndexSet(
        rows.indices.filter { index in
          rows[index].scheduledRows.contains { row in
            row.spins.contains { $0.spinGroupId.map(groupIds.contains) ?? false }
          }
        }))
  }

  private func rememberPendingPositions(in rows: [AMAPlaylistRowData]) {
    for (index, row) in rows.enumerated() {
      for pending in row.pendingRows {
        pendingPredecessors[pending.id] = rows.prefix(index).map(\.id).reversed()
      }
    }
  }

  private func canInsertBefore(_ row: AMALiveRowData) -> Bool {
    !row.spins.isEmpty && row.id != endingSpinId
      && !(isWaitingToAir && row.spins.first?.airtime == scheduledStartsAt)
      && row.spins.allSatisfy { broadcast.canDeleteSpin($0) }
  }
}
