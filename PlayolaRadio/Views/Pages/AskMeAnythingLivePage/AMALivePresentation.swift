import PlayolaPlayer
import SwiftUI

struct AMALiveRowData: Identifiable {
  let spins: [Spin]
  let title: String
  let subtitle: String
  let icon: String
  let artworkURL: URL?
  let artworkColor: Color
  let airtime: String
  let trailingIcon: String
  let isEditable: Bool
  var id: String { spins[0].id }
}

extension AskMeAnythingLivePageModel {
  func playbackTick() {
    broadcast.tick()
    schedulePlaybackChanged()
  }

  func updateLivePresentation() {
    guard let showId = broadcast.liveShowId, let schedule = broadcast.schedule else { return }
    displayDate = now
    let showSpins = schedule.current().filter { $0.liveShowId == showId }
    if scheduledStartsAt == nil { scheduledStartsAt = showSpins.first?.airtime }
    let filler = showSpins.filter { $0.isFiller == true }
    broadcast.visibleFillerIds.formIntersection(Set(filler.map(\.id)))
    let newlyVisible = filler.filter {
      $0.airtime <= displayDate.addingTimeInterval(180)
        && !broadcast.visibleFillerIds.contains($0.id)
    }
    broadcast.visibleFillerIds.formUnion(newlyVisible.map(\.id))
    if hasPresentedSchedule, let promoted = newlyVisible.last, promoted.airtime > displayDate {
      lastPromotedFiller = (promoted.audioBlock.title, displayDate)
    }
    hasPresentedSchedule = true
  }

  func loadLiveMetadata() async {
    guard let jwt = auth.jwt else { return }
    async let sessions = try? api.getActiveListeningSessions(jwt, stationId, now, nil)
    async let questions = try? api.getListenerQuestions(jwt, stationId)
    listenerCount = await sessions?.summary.uniqueUsers
    if let questions = await questions { listenerQuestions = questions }
  }

  var isWaitingToAir: Bool {
    isShowActive && displayDate != .distantPast
      && (scheduledStartsAt.map { $0 > displayDate } ?? false)
  }
  var waitingHeight: CGFloat { isWaitingToAir ? 64 : 0 }
  var waitingOpacity: Double { isWaitingToAir ? 1 : 0 }
  var waitingFooterHeight: CGFloat { isWaitingToAir ? 40 : 0 }
  var liveFooterHeight: CGFloat { isWaitingToAir ? 0 : (bufferMessage.isEmpty ? 112 : 142) }
  var liveFooterOpacity: Double { isWaitingToAir ? 0 : 1 }
  var setupHeaderHeight: CGFloat { isShowActive ? 0 : 44 }
  var listenerCountLabel: String { listenerCount.map { "\($0) listening" } ?? "— listening" }
  var waitingTitle: String {
    "Your Show Starts in \(secondsLabel(scheduledStartsAt?.timeIntervalSince(displayDate) ?? 0))"
  }
  var waitingSubtitle: String {
    guard let starts = scheduledStartsAt else { return "" }
    return "After \(nowPlayingTitle) finishes · \(airtimeString(starts))"
  }
  var waitingFooterLabel: String { "Show starts automatically" }
  var nowPlayingTitle: String { broadcast.nowPlaying?.audioBlock.title ?? "Your station" }
  var nowPlayingArtist: String { broadcast.nowPlaying?.audioBlock.artist ?? "" }
  var nowPlayingArtworkURL: URL? { broadcast.nowPlaying?.audioBlock.imageUrl }
  var nowPlayingProgress: Double { broadcast.nowPlaying?.progress(at: displayDate) ?? 0 }
  var liveNowLabel: String { "LIVE NOW" }
  var liveAddTitle: String { "Add to Show" }
  var liveAddExplanation: String {
    if isAddingToShow { return "Adding to your playlist…" }
    if !pendingAddIds.isEmpty { return "Audio is ready. Retry adding it below." }
    if openingItems.contains(where: { !$0.isReady }) { return "Uploading your voicetrack…" }
    return "Added to the end of your playlist"
  }
  var retryAddLabel: String { "Retry adding audio" }
  var pendingAddIds: [String] { broadcast.stagingItems.map(\.stagingId) }
  var canAddLiveAudio: Bool { isEndShowEnabled && !isAddingToShow }
  var deleteRowLabel: String { "Delete" }

  private var nextReserveFiller: Spin? {
    broadcast.schedule?.current().first {
      $0.liveShowId == broadcast.liveShowId && $0.isFiller == true
        && !broadcast.visibleFillerIds.contains($0.id)
    }
  }
  var bufferedSeconds: TimeInterval {
    let end = broadcast.schedule?.current().filter {
      $0.liveShowId == broadcast.liveShowId
        && ($0.isFiller != true || broadcast.visibleFillerIds.contains($0.id))
    }.map(\.endtime).max()
    return max(0, end?.timeIntervalSince(displayDate) ?? 0)
  }
  var bufferLabel: String { "\(secondsLabel(bufferedSeconds)) buffered" }
  var bufferProgress: Double { min(1, bufferedSeconds / 600) }
  var bufferPercentLabel: String { "\(Int((bufferProgress * 100).rounded()))% of 10 min" }
  var isBufferLow: Bool { bufferedSeconds <= 210 }
  var bufferColor: Color { isBufferLow ? .playolaBufferAmber : .playolaSuccessGreen }
  var bufferTextColor: Color { isBufferLow ? .playolaBufferAmber : .playolaTextPrimary }
  var bufferMessage: String {
    if isBufferLow, let filler = nextReserveFiller {
      return "Adding \(filler.audioBlock.title) in "
        + secondsLabel(filler.airtime.timeIntervalSince(displayDate) - 180)
    }
    if let promoted = lastPromotedFiller, displayDate.timeIntervalSince(promoted.date) < 5 {
      return "\(promoted.title) added to keep your show going"
    }
    return ""
  }
  var bufferMessageColor: Color { isBufferLow ? .playolaBufferAmber : .playolaTextSecondary }
  var bufferMessageFont: Font {
    .custom(
      isBufferLow ? FontNames.Inter_600_SemiBold : FontNames.Inter_400_Regular,
      size: isBufferLow ? 13 : 12)
  }
  var bufferMessages: [String] { bufferMessage.isEmpty ? [] : [bufferMessage] }

  var liveRows: [AMALiveRowData] {
    let spins = broadcast.upcomingSpins
    var consumed: Set<String> = []
    return spins.compactMap { spin in
      guard !consumed.contains(spin.id) else { return nil }
      let question = listenerQuestions.first {
        $0.audioBlockId == spin.audioBlock.id || $0.answerAudioBlockId == spin.audioBlock.id
      }
      let pair = spins.filter {
        question != nil && spin.spinGroupId != nil && $0.spinGroupId == spin.spinGroupId
      }
      let members = pair.isEmpty ? [spin] : pair
      consumed.formUnion(members.map(\.id))
      let isIntro = isWaitingToAir && spin.airtime == scheduledStartsAt
      let isVoice = spin.audioBlock.type == "voiceTrack"
      let title =
        question.map { "Question and Answer: \($0.listener?.firstName ?? "Listener")" }
        ?? (isIntro ? "Show Intro" : (isVoice ? "VoiceTrack" : spin.audioBlock.title))
      let duration = secondsLabel(
        members.reduce(0) { $0 + $1.endtime.timeIntervalSince($1.airtime) })
      let subtitle: String
      if question != nil {
        subtitle = "\(duration) · Question and answer"
      } else if isIntro {
        subtitle = "Your voice"
      } else if isVoice {
        subtitle = "\(duration) · Your voice"
      } else {
        subtitle = spin.audioBlock.artist + (isWaitingToAir ? "" : " · \(duration)")
      }
      let editable = !isIntro && members.allSatisfy { broadcast.canDeleteSpin($0) }
      return AMALiveRowData(
        spins: members, title: title, subtitle: subtitle,
        icon: question != nil
          ? "messages-square" : (isIntro || isVoice ? "mic" : "music"),
        artworkURL: question != nil || isIntro || isVoice ? nil : spin.audioBlock.imageUrl,
        artworkColor: question != nil || isIntro || isVoice ? .playolaRed : .playolaSurfaceMuted,
        airtime: "at \(airtimeString(spin.airtime))",
        trailingIcon: isIntro ? "pin" : (editable ? "menu" : "lock-keyhole"),
        isEditable: editable)
    }
  }

  func deleteLiveRow(_ row: AMALiveRowData) async {
    guard let current = liveRows.first(where: { $0.id == row.id }), current.isEditable
    else { return }
    // The existing endpoint deletes one spin. Delete the answer first so the
    // question's airtime does not move across the safety boundary mid-operation.
    for member in current.spins.reversed() {
      guard let latest = broadcast.schedule?.current().first(where: { $0.id == member.id }),
        broadcast.canDeleteSpin(latest)
      else { return }
      await broadcast.deleteSpin(latest)
      if broadcast.schedule?.current().contains(where: { $0.id == member.id }) == true { return }
    }
    schedulePlaybackChanged()
  }

  func moveLiveRows(from source: IndexSet, to destination: Int) async {
    let rows = liveRows
    guard source.allSatisfy({ rows.indices.contains($0) && rows[$0].isEditable }),
      destination >= 0, destination <= rows.count,
      destination == rows.count || rows[destination].isEditable
    else { return }
    let spins = broadcast.upcomingSpins
    let moving = Set(source.flatMap { rows[$0].spins.map(\.id) })
    let indices = IndexSet(spins.indices.filter { moving.contains(spins[$0].id) })
    let target =
      destination == rows.count
      ? spins.count
      : spins.firstIndex(where: { $0.id == rows[destination].id }) ?? spins.count
    await broadcast.moveSpins(from: indices, to: target)
    schedulePlaybackChanged()
  }

  func appendToShow(_ audioBlock: AudioBlock, showId: String) async {
    guard broadcast.liveShowId == showId else { return }
    if !broadcast.stagingItems.contains(where: { $0.stagingId == audioBlock.id }) {
      broadcast.stagingItems.append(audioBlock)
    }
    await retryAddingAudio()
  }

  func retryAddingAudio() async {
    guard canAddLiveAudio, auth.jwt != nil else { return }
    isAddingToShow = true
    defer { isAddingToShow = false }
    while let item = broadcast.stagingItems.first {
      guard let target = broadcast.showEndDropTargets.first else {
        presentedAlert = PlayolaAlert(
          title: "Unable to Add Audio",
          message: "Refresh the show and try again. Your audio is ready to retry.",
          dismissButton: .cancel(Text("OK")))
        return
      }
      await broadcast.insertStagingItem(stagingId: item.stagingId, beforeSpinId: target)
      guard !broadcast.stagingItems.contains(where: { $0.stagingId == item.stagingId }) else {
        return
      }
      schedulePlaybackChanged()
    }
  }

  private func secondsLabel(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds).rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
  private func airtimeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter.string(from: date).lowercased()
  }
}
