//
//  VoicetrackStatusResponse.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/16/25.
//

import Foundation

struct VoicetrackStatusResponse: Decodable, Equatable {
  let ready: Bool
  let s3Key: String
}
