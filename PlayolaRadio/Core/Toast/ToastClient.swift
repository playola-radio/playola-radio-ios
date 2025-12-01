//
//  ToastClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct ToastClient {
  public var show: @Sendable (PlayolaToast) async -> Void
  public var currentToast: @Sendable () async -> PlayolaToast?
  public var dismiss: @Sendable () async -> Void
  public var stream: @Sendable () -> AsyncStream<PlayolaToast?> = { AsyncStream { _ in } }
}

extension ToastClient: DependencyKey {
  public static var liveValue: ToastClient {
    let toastState = ToastState()

    return ToastClient(
      show: { toast in
        await toastState.show(toast)
      },
      currentToast: {
        await toastState.currentToast
      },
      dismiss: {
        await toastState.dismiss()
      },
      stream: {
        AsyncStream { continuation in
          Task {
            await toastState.setContinuation(continuation)
          }
        }
      }
    )
  }
}

extension ToastClient: TestDependencyKey {
  public static let testValue = ToastClient.noop
}

extension ToastClient {
  static let noop = ToastClient(
    show: { _ in },
    currentToast: { nil },
    dismiss: {},
    stream: {
      AsyncStream { continuation in
        continuation.finish()
      }
    }
  )
}

private actor ToastState {
  private(set) var currentToast: PlayolaToast?
  private var toastQueue: [PlayolaToast] = []
  private var dismissTask: Task<Void, Never>?
  private var continuation: AsyncStream<PlayolaToast?>.Continuation?
  @Dependency(\.continuousClock) var clock

  func setContinuation(_ continuation: AsyncStream<PlayolaToast?>.Continuation) {
    self.continuation = continuation
    continuation.yield(currentToast)
  }

  func show(_ toast: PlayolaToast) {
    toastQueue.append(toast)
    if currentToast == nil {
      Task {
        await showNext()
      }
    }
  }

  func dismiss() {
    dismissTask?.cancel()
    dismissTask = nil
    currentToast = nil
    continuation?.yield(nil)
    Task {
      await showNext()
    }
  }

  private func showNext() async {
    guard currentToast == nil, !toastQueue.isEmpty else { return }

    let toast = toastQueue.removeFirst()
    currentToast = toast
    continuation?.yield(toast)

    dismissTask = Task {
      try? await clock.sleep(for: .seconds(toast.duration))
      guard !Task.isCancelled else { return }
      currentToast = nil
      continuation?.yield(nil)
      await showNext()
    }
  }
}

extension DependencyValues {
  public var toast: ToastClient {
    get { self[ToastClient.self] }
    set { self[ToastClient.self] = newValue }
  }
}
