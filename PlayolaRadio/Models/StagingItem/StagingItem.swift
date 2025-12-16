//
//  StagingItem.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import PlayolaPlayer
import SwiftUI

protocol StagingItem {
  var stagingId: String { get }
  var titleText: String { get }
  var subtitleText: String { get }
  var subtitleColor: Color { get }
  var albumImageUrl: URL? { get }
  var icon: String? { get }
  var audioBlockId: String? { get }
  var isReady: Bool { get }
  var isProcessing: Bool { get }
}

// MARK: - LocalVoicetrack Conformance

extension LocalVoicetrack: StagingItem {
  var stagingId: String {
    id.uuidString
  }

  var titleText: String {
    title
  }

  var subtitleText: String {
    switch status {
    case .converting:
      return "Converting..."
    case .uploading(let progress):
      return "Uploading \(Int(progress * 100))%"
    case .finalizing:
      return "Finalizing..."
    case .completed:
      return "Ready"
    case .failed(let error):
      return error
    }
  }

  var subtitleColor: Color {
    switch status {
    case .completed:
      return .green
    case .failed:
      return .playolaRed
    default:
      return .playolaGray
    }
  }

  var albumImageUrl: URL? {
    nil
  }

  var icon: String? {
    "mic.fill"
  }

  var isReady: Bool {
    isComplete && audioBlockId != nil
  }
}

// MARK: - AudioBlock Conformance

extension AudioBlock: StagingItem {
  public var stagingId: String {
    id
  }

  public var titleText: String {
    title
  }

  public var subtitleText: String {
    artist
  }

  public var subtitleColor: Color {
    .playolaGray
  }

  public var albumImageUrl: URL? {
    imageUrl
  }

  public var icon: String? {
    nil
  }

  public var audioBlockId: String? {
    id
  }

  public var isReady: Bool {
    true
  }

  public var isProcessing: Bool {
    false
  }
}
