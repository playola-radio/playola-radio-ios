//
//  AppVersionRequirements.swift
//  PlayolaRadio
//

import Foundation

struct AppVersionRequirements: Codable, Equatable, Sendable {
  let minimumVersion: String
  let minimumBroadcasterVersion: String
}
