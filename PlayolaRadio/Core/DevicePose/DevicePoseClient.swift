//
//  DevicePoseClient.swift
//  PlayolaRadio
//

import CoreMotion
import Dependencies
import DependenciesMacros
import Foundation

/// How the phone is physically held, from the gravity vector. Face-up, face-down, landscape and
/// in-between readings are `.indeterminate` so they never count as a flip in either direction.
enum DevicePose: Equatable, Sendable {
  case upright
  case upsideDown
  case indeterminate

  static let threshold = 0.65

  init(gravityX: Double, gravityY: Double) {
    guard abs(gravityY) >= Self.threshold, abs(gravityY) > abs(gravityX) else {
      self = .indeterminate
      return
    }
    self = gravityY < 0 ? .upright : .upsideDown
  }
}

@DependencyClient
struct DevicePoseClient: Sendable {
  /// Emits the current pose immediately, then every motion sample until the stream is cancelled.
  var updates: @Sendable () -> AsyncStream<DevicePose> = { AsyncStream { $0.finish() } }
}

extension DevicePoseClient: TestDependencyKey {
  static let testValue = DevicePoseClient()
}

extension DependencyValues {
  var devicePose: DevicePoseClient {
    get { self[DevicePoseClient.self] }
    set { self[DevicePoseClient.self] = newValue }
  }
}

extension DevicePoseClient: DependencyKey {
  static var liveValue: Self {
    Self(
      updates: {
        AsyncStream { continuation in
          nonisolated(unsafe) let manager = CMMotionManager()
          guard manager.isDeviceMotionAvailable else {
            continuation.finish()
            return
          }
          let queue = OperationQueue()
          queue.maxConcurrentOperationCount = 1
          manager.deviceMotionUpdateInterval = 1.0 / 20
          manager.startDeviceMotionUpdates(to: queue) { motion, _ in
            guard let gravity = motion?.gravity else {
              continuation.finish()
              return
            }
            continuation.yield(DevicePose(gravityX: gravity.x, gravityY: gravity.y))
          }
          continuation.onTermination = { _ in manager.stopDeviceMotionUpdates() }
        }
      }
    )
  }
}
