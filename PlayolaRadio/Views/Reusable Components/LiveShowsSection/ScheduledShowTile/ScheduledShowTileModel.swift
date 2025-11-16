//
//  ScheduledShowTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//
import Dependencies
import Observation

@Observable
class ScheduledShowTileModel {
  var scheduledShow: ScheduledShow

  init(scheduledShow: ScheduledShow) {
    self.scheduledShow = scheduledShow
  }

  @ObservationIgnored
  @Dependency(\.date.now) var now

  var isLive: Bool { return scheduledShow.isLive }

  enum ScheduledShowTileButtonType
  {
    case listenNow
    case remindMe
  }

  var buttonType: ScheduledShowTileButtonType {
    if scheduledShow.airtime.addingTimeInterval(60 * -5) > self.now {
      return .remindMe
    }
    return .listenNow
  }
}
