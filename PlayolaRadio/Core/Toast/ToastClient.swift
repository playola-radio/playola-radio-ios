//
//  ToastClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import ComposableArchitecture
import Dependencies
import Foundation

@DependencyClient
public struct ToastClient {
  public var show: @Sendable (PlayolaToast) async -> Void
  public var currentToast: @Sendable () async -> PlayolaToast?
  public var dismiss: @Sendable () async -> Void
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
    dismiss: {}
  )
}

private actor ToastState {
  private(set) var currentToast: PlayolaToast?
  private var toastQueue: [PlayolaToast] = []
  private var dismissTask: Task<Void, Never>?
  @Dependency(\.continuousClock) var clock

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
    Task {
      await showNext()
    }
  }

  private func showNext() async {
    guard currentToast == nil, !toastQueue.isEmpty else { return }

    let toast = toastQueue.removeFirst()
    currentToast = toast

    dismissTask = Task {
      try? await clock.sleep(for: .seconds(toast.duration))
      guard !Task.isCancelled else { return }
      currentToast = nil
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
