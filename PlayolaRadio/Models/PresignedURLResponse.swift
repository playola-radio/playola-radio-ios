//
//  PresignedUrlResponse.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Foundation

struct PresignedURLResponse: Decodable, Equatable {
  let presignedUrl: URL
  let s3Key: String
  let voicetrackUrl: URL
}
