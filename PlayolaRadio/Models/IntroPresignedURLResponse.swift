//
//  IntroPresignedURLResponse.swift
//  PlayolaRadio
//

import Foundation

struct IntroPresignedURLResponse: Decodable, Equatable {
  let presignedUrl: URL
  let s3Key: String
}
