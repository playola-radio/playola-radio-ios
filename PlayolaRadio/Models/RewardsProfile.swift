//
//  RewardsProfile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//

import Foundation

struct RewardsProfile: Decodable {
  let totalTimeListenedMS: Int
  let totalMSAvailableForRewards: Int
  let accurateAsOfTime: String
}
