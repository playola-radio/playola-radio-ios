//
//  PresignedUrlUploadInfo.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/13/25.
//

struct PresignedUrlUploadInfo: Decodable {
  let presignedUrl: String
  let s3Key: String
}
