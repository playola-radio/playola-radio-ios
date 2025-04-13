//
//  LocalVoicetrack.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/11/25.
//
import Foundation

public struct LocalVoicetrack: Identifiable, Equatable, Sendable {
  public let id: String
  public let fileURL: URL
  public let durationMS: Int
  
  init(id: String = UUID().uuidString, fileURL: URL, durationMS: Int) {
    self.id = id
    self.fileURL = fileURL
    self.durationMS = durationMS
  }
}
