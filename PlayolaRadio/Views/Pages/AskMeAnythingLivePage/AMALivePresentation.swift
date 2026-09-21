import PlayolaPlayer
import SwiftUI

struct AMALiveRowData: Identifiable {
  let id: String
  let spins: [Spin]
  let title: String
  let subtitle: String
  let icon: String
  let artworkURL: URL?
  let artworkColor: Color
  let airtime: String
  let trailingIcon: String
  let isEditable: Bool
  let isProcessing: Bool
  var processingOpacity: Double { isProcessing ? 1 : 0 }
  var airtimeOpacity: Double { isProcessing ? 0 : 1 }
  var processingLabel: String { "Updating schedule" }
}

extension AskMeAnythingLivePageModel {
  func playbackTick() {
    if isAwaitingStartedSchedule { displayDate = now }
    broadcast.tick()
    schedulePlaybackChanged()
  }

  func updateLivePresentation() {
    if isAwaitingStartedSchedule { displayDate = now }
    guard let showId = broadcast.liveShowId, let schedule = broadcast.schedule else { return }
    displayDate = now
    if let endingSpinId, schedule.spins.contains(where: { $0.id == endingSpinId }),
      let outroStagingId
    {
      broadcast.stagingItems.removeAll { $0.stagingId == outroStagingId }
      pendingPredecessors[outroStagingId] = nil
    }
    if isAwaitingStartedSchedule, schedule.spins.contains(where: { $0.liveShowId == showId }) {
      isAwaitingStartedSchedule = false
      openingItems.removeAll()
    }
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
  var liveAddExplanation: String { "Added to the end of your playlist" }
  var isScheduleProcessing: Bool {
    isStartingShow || isAddingToShow || isEditingSchedule || isEndingShow || broadcast.isLoading
  }
  var liveScheduleRetryTitles: [String] { scheduleRetryVisible ? [scheduleRetryTitle] : [] }
  var canEditLiveQueue: Bool { !isScheduleProcessing && !isAwaitingStartedSchedule }
  var canAddLiveAudio: Bool {
    isShowActive && !isAwaitingStartedSchedule && !isStartingShow && !isEndingShow
      && !isEditingSchedule && !broadcast.isLoading && !isCheckingSchedule
      && outroStagingId == nil && effectiveEndsAt == nil
  }
  var canAddQuestion: Bool { canAddLiveAudio && !isScheduleProcessing }
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
    if isAwaitingStartedSchedule {
      return openingRows.map { row in
        AMALiveRowData(
          id: row.id.uuidString, spins: [], title: row.title, subtitle: row.subtitle,
          icon: row.iconSystemName == "music.note" ? "music" : "mic",
          artworkURL: row.albumImageUrl,
          artworkColor: row.iconSystemName == "music.note" ? .playolaSurfaceMuted : .playolaRed,
          airtime: "", trailingIcon: row.trailingIconSystemName == "pin" ? "pin" : "lock-keyhole",
          isEditable: false, isProcessing: isScheduleProcessing)
      }
    }
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
      let isOutro = spin.id == endingSpinId
      let isVoice = spin.audioBlock.type == "voiceTrack"
      let title =
        question.map { "Question and Answer: \($0.listener?.firstName ?? "Listener")" }
        ?? (isIntro
          ? "Show Intro"
          : (isOutro ? "Show Outro" : (isVoice ? "VoiceTrack" : spin.audioBlock.title)))
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
      let editable =
        canEditLiveQueue && !isIntro && !isOutro
        && members.allSatisfy { broadcast.canDeleteSpin($0) }
      return AMALiveRowData(
        id: spin.id, spins: members, title: title, subtitle: subtitle,
        icon: question != nil
          ? "messages-square" : (isIntro || isVoice ? "mic" : "music"),
        artworkURL: question != nil || isIntro || isVoice ? nil : spin.audioBlock.imageUrl,
        artworkColor: question != nil || isIntro || isVoice ? .playolaRed : .playolaSurfaceMuted,
        airtime: "at \(airtimeString(spin.airtime))",
        trailingIcon: isIntro ? "pin" : (editable ? "menu" : "lock-keyhole"),
        isEditable: editable,
        isProcessing: members.contains { broadcast.spinIdsBeingRescheduled.contains($0.id) })
    }
  }

  func deleteLiveRow(_ row: AMALiveRowData) async {
    guard let current = liveRows.first(where: { $0.id == row.id }), current.isEditable
    else { return }
    isEditingSchedule = true
    // The existing endpoint deletes one spin. Delete the answer first so the
    // question's airtime does not move across the safety boundary mid-operation.
    for member in current.spins.reversed() {
      guard let latest = broadcast.schedule?.current().first(where: { $0.id == member.id }),
        broadcast.canDeleteSpin(latest)
      else { break }
      await broadcast.deleteSpin(latest)
      if broadcast.schedule?.current().contains(where: { $0.id == member.id }) == true { break }
    }
    isEditingSchedule = false
    schedulePlaybackChanged()
    await schedulePendingAudio()
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
