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
}
