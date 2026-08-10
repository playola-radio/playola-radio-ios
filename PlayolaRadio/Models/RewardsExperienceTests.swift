//
//  RewardsExperienceTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct RewardsExperienceTests {
  private func decodeProfile(_ json: String) throws -> RewardsProfile {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(RewardsProfile.self, from: Data(json.utf8))
  }

  @Test func absentRewardsExperienceIsFullTiers() throws {
    let profile = try decodeProfile(
      #"""
      {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z"}
      """#)
    #expect(profile.rewardsExperienceType == .fullTiers)
    #expect(profile.koozieEarned == nil)
    #expect(profile.shouldShowKoozieCongrats == nil)
  }

  @Test func koozieOnlyStringIsKoozieOnly() throws {
    let profile = try decodeProfile(
      #"""
      {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z","rewardsExperience":"koozie_only","koozieEarned":true,"shouldShowKoozieCongrats":true}
      """#)
    #expect(profile.rewardsExperienceType == .koozieOnly)
    #expect(profile.koozieEarned == true)
    #expect(profile.shouldShowKoozieCongrats == true)
  }

  @Test func unknownRewardsExperienceFallsBackToFullTiers() throws {
    let profile = try decodeProfile(
      #"""
      {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z","rewardsExperience":"some_future_tier_v3"}
      """#)
    #expect(profile.rewardsExperienceType == .fullTiers)
  }

  @Test func prizeSlugDecodes() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let withSlug = try decoder.decode(
      Prize.self,
      from: Data(
        #"""
        {"id":"p1","name":"Playola Koozie","prizeTierId":"t1","slug":"koozie","createdAt":"2026-09-20T14:00:00Z","updatedAt":"2026-09-20T14:00:00Z"}
        """#.utf8))
    #expect(withSlug.slug == "koozie")
    let withoutSlug = try decoder.decode(
      Prize.self,
      from: Data(
        #"""
        {"id":"p2","name":"Tee","prizeTierId":"t2","createdAt":"2026-09-20T14:00:00Z","updatedAt":"2026-09-20T14:00:00Z"}
        """#.utf8))
    #expect(withoutSlug.slug == nil)
  }

  @Test func kooziePrizeInfoLocatesBySlug() {
    let tiers = [
      PrizeTier(
        id: "tier-koozie", name: "Koozie", requiredListeningHours: 50, imageIconUrl: nil,
        prizes: [
          Prize(
            id: "prize-koozie", name: "Playola Koozie", prizeTierId: "tier-koozie", imageUrl: nil,
            slug: "koozie")
        ]),
      PrizeTier(
        id: "tier-tshirt", name: "T-Shirt", requiredListeningHours: 100, imageIconUrl: nil,
        prizes: [
          Prize(
            id: "prize-tshirt", name: "Tee", prizeTierId: "tier-tshirt", imageUrl: nil,
            slug: "tshirt")
        ]),
    ]
    let info = tiers.kooziePrizeInfo
    #expect(info?.prizeId == "prize-koozie")
    #expect(info?.requiredHours == 50)
    #expect(info?.prizeName == "Playola Koozie")
  }

  @Test func kooziePrizeInfoIsNilWhenNoKoozieSlug() {
    let tiers = [
      PrizeTier(
        id: "tier-tshirt", name: "T-Shirt", requiredListeningHours: 100, imageIconUrl: nil,
        prizes: [
          Prize(
            id: "prize-tshirt", name: "Tee", prizeTierId: "tier-tshirt", imageUrl: nil,
            slug: "tshirt")
        ])
    ]
    #expect(tiers.kooziePrizeInfo == nil)
  }
}
