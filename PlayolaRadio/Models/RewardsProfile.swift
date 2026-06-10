//
//  RewardsProfile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//
import Foundation

struct RewardsProfile: Codable, Sendable {
  let totalTimeListenedMS: Int
  let totalMSAvailableForRewards: Int
  let accurateAsOfTime: Date

  // Server-computed welcome-message eligibility. `var` + default so the synthesized
  // memberwise init stays source-compatible with existing call sites while the optional
  // is still decoded (decodeIfPresent → nil when the server omits it).
  var shouldShowWelcomeMessage: Bool?
}
