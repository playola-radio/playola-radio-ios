//
//  AudioConverterClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import AVFoundation
import Dependencies

public struct AudioConverterClient: Sendable {
  public var convertToM4A: @Sendable (URL) async throws -> URL
  public var getDuration: @Sendable (URL) async throws -> Int
}

// MARK: - Live Implementation

extension AudioConverterClient: DependencyKey {
  public static var liveValue: AudioConverterClient {
    AudioConverterClient(
      convertToM4A: { inputURL in
        let asset = AVURLAsset(url: inputURL)

        guard
          let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
          )
        else {
          throw AudioConverterError.exportSessionCreationFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("voicetrack_\(UUID().uuidString).m4a")

        do {
          try await exportSession.export(to: outputURL, as: .m4a)
          return outputURL
        } catch let error as AVError where error.code == .cancelled {
          throw AudioConverterError.conversionCancelled
        } catch {
          throw AudioConverterError.conversionFailed
        }
      },
      getDuration: { url in
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return Int(CMTimeGetSeconds(duration) * 1000)
      }
    )
  }
}

// MARK: - Test Implementation

extension AudioConverterClient: TestDependencyKey {
  public static var testValue: AudioConverterClient {
    AudioConverterClient(
      convertToM4A: { _ in URL(fileURLWithPath: "/tmp/test.m4a") },
      getDuration: { _ in 15000 }
    )
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  public var audioConverter: AudioConverterClient {
    get { self[AudioConverterClient.self] }
    set { self[AudioConverterClient.self] = newValue }
  }
}

// MARK: - Errors

enum AudioConverterError: Error, LocalizedError {
  case exportSessionCreationFailed
  case conversionFailed
  case conversionCancelled

  var errorDescription: String? {
    switch self {
    case .exportSessionCreationFailed:
      return "Failed to create audio export session"
    case .conversionFailed:
      return "Audio conversion failed"
    case .conversionCancelled:
      return "Audio conversion was cancelled"
    }
  }
}
