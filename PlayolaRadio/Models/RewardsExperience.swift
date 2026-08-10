//
//  RewardsExperience.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Foundation

/// Which rewards experience the server has assigned this user. Absent/null/unrecognized
/// server values fall back to `.fullTiers` (never koozie-only) per the project's
/// "server enums need a safe unknown fallback" rule.
enum RewardsExperience: Equatable, Sendable {
  case fullTiers
  case koozieOnly

  init(rawServerValue: String?) {
    switch rawServerValue {
    case "koozie_only": self = .koozieOnly
    default: self = .fullTiers
    }
  }
}

/// The koozie prize's identity + threshold, located in the public `/tiers` response by
/// `slug == "koozie"`. Nil when no koozie prize exists (older server / non-koozie data).
struct KooziePrizeInfo: Equatable, Sendable {
  let prizeId: String
  let prizeName: String
  let requiredHours: Int
}

extension Array where Element == PrizeTier {
  /// Locates the koozie prize by `slug == "koozie"` and returns its id, name, and its
  /// tier's `requiredListeningHours`. Keys off the slug, never a hardcoded UUID.
  var kooziePrizeInfo: KooziePrizeInfo? {
    for tier in self {
      if let prize = tier.prizes.first(where: { $0.slug == "koozie" }) {
        return KooziePrizeInfo(
          prizeId: prize.id, prizeName: prize.name, requiredHours: tier.requiredListeningHours)
      }
    }
    return nil
  }
}
