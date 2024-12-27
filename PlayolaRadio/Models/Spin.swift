//
//  Spin.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/25/24.
//
import Foundation

struct Spin: Codable {
  var id: String
  var airtime: Date
  var createdAt: Date
  var updatedAt: Date
  var stationId: String
  var audioBlock: AudioBlock?
}
