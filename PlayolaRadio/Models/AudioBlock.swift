//
//  AudioBlock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/24/24.
//

import Foundation

struct AudioBlock: Codable {
  let endOfMessageMS: Int
  let beginningOfOutroMS: Int
  let endOfIntroMS: Int
  let lengthOfOutroMS: Int
  let downloadUrl: String
  let id: UUID
  let type: String
  let title: String
  let artist: String
  let album: String?
  let durationMS: Int
  let popularity: Int?
  let youTubeId: Int?
  let s3Key: String
  let s3BucketName: String
  let isrc: String?
  let spotifyId: String?
  let imageUrl: String?
  let createdAt: Date
  let updatedAt: Date
}
