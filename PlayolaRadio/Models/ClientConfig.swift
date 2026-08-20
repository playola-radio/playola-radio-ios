//
//  ClientConfig.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/26.
//

import Foundation

/// Per-user, server-driven client configuration fetched first thing at launch.
/// Deliberately minimal — a typed home for cross-cutting client flags, not a
/// feature-flag platform. Fields are optional `var`s so synthesized Decodable
/// uses decodeIfPresent (absent ⇒ nil ⇒ conservative default at the projection
/// site) and the memberwise init stays source-compatible as fields are added.
struct ClientConfig: Codable, Equatable, Sendable {
  /// Opt-in for the SDK's sample-buffer render backend (AirPlay-2 long-form,
  /// PlayolaPlayer 0.21.0+). Absent ⇒ false ⇒ legacy engine.
  var sampleBufferRendererEnabled: Bool?
}
