//
//  Version+Comparison.swift
//  PlayolaRadio
//

import Foundation

func isVersion(_ version: String, lessThan required: String) -> Bool {
  let versionParts = version.split(separator: ".").compactMap { Int($0) }
  let requiredParts = required.split(separator: ".").compactMap { Int($0) }

  let maxCount = max(versionParts.count, requiredParts.count)
  for index in 0..<maxCount {
    let current = index < versionParts.count ? versionParts[index] : 0
    let minimum = index < requiredParts.count ? requiredParts[index] : 0
    if current < minimum { return true }
    if current > minimum { return false }
  }
  return false
}
