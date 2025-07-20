//
//  RewardsProfile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/20/25.
//

import Combine
import Dependencies
import Foundation

struct RewardsProfile: Decodable {
  let totalTimeListenedMS: Int
  let totalMSAvailableForRewards: Int
  let accurateAsOfTime: Date
}
