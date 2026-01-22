//
//  ListenerQuestionPresignedURLResponse.swift
//  PlayolaRadio
//

import Foundation

struct ListenerQuestionPresignedURLResponse: Decodable, Equatable {
  let presignedUrl: URL
  let s3Key: String
  let questionUrl: URL
}
