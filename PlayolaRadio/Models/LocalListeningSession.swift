//
//  LocalListeningSession.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//
import Foundation

struct LocalListeningSession {
  var startTime: Date!
  var endTime: Date?

  var totalTimeMS: Int {
    let finishTime: Date = endTime ?? .now
    return Int(finishTime.timeIntervalSince(startTime) * 1000)
  }
}
