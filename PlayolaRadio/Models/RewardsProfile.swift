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

  // Koozie-only cohort fields (self-only, all optional). Absent ⇒ today's full-tiers
  // behavior. Same `var` + default rationale as `shouldShowWelcomeMessage`: synthesized
  // Decodable uses decodeIfPresent for optionals, and the memberwise init stays
  // source-compatible with existing positional call sites.
  var rewardsExperience: String?
  var koozieEarned: Bool?
  var shouldShowKoozieCongrats: Bool?

  var rewardsExperienceType: RewardsExperience {
    RewardsExperience(rawServerValue: rewardsExperience)
  }
}
