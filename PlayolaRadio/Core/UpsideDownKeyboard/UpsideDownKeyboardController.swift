//
//  UpsideDownKeyboardController.swift
//  PlayolaRadio
//

import SwiftUI
import UIKit

/// While the app window is flipped upside down, the system keyboard still appears right-side
/// up because it lives in a system window. This swaps it for `UpsideDownKeyboardView`, drawn in
/// an overlay window with the same rotation as the app.
///
/// The custom keyboard is only ever shown when upside-down mode is enabled, a text field or
/// text view is editing, and that field's window is actually rotated.
@MainActor
final class UpsideDownKeyboardController {
  let keyboardModel = UpsideDownKeyboardModel()

  private let keyboardHeight: CGFloat = 260
  private var isModeEnabled = false
  private weak var target: UIView?
  private var suppressedInput: SuppressedInput?
  private var insetBaselines: [InsetBaseline] = []
  private var overlayWindow: KeyboardOverlayWindow?
  private var keyboardBottomConstraint: NSLayoutConstraint?
  private var observers: [NSObjectProtocol] = []

  var isShowingCustomKeyboard: Bool { overlayWindow?.isHidden == false }

  init() {
    keyboardModel.onCommand = { [weak self] command in self?.perform(command) }
  }

  isolated deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  func start() {
    guard observers.isEmpty else { return }
    observers = [
      observe(UITextField.textDidBeginEditingNotification) { $0.editingBegan($1) },
      observe(UITextView.textDidBeginEditingNotification) { $0.editingBegan($1) },
      observe(UITextField.textDidEndEditingNotification) { $0.editingEnded($1) },
      observe(UITextView.textDidEndEditingNotification) { $0.editingEnded($1) },
    ]
  }

  func setUpsideDownModeEnabled(_ isEnabled: Bool) {
    isModeEnabled = isEnabled
    reconcile()
  }

  func editingBegan(_ input: UIView) {
    if input !== target {
      hideCustomKeyboard()
      target = input
      keyboardModel.editingBegan()
    }
    reconcile()
  }

  func editingEnded(_ input: UIView) {
    guard input === target else { return }
    hideCustomKeyboard()
    target = nil
  }

  // MARK: - Private Helpers

  private func observe(
    _ name: Notification.Name,
    handler: @escaping @MainActor @Sendable (UpsideDownKeyboardController, UIView) -> Void
  ) -> NSObjectProtocol {
    NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
      [weak self] notification in
      let input = notification.object as? UIView
      MainActor.assumeIsolated {
        guard let self, let input else { return }
        handler(self, input)
      }
    }
  }

  private func reconcile() {
    guard isModeEnabled, let target, let window = target.window, window.transform.a < 0 else {
      hideCustomKeyboard()
      return
    }
    suppressSystemKeyboard(for: target)
    applyInsets(in: window)
    showOverlay(over: window)
  }

  private func hideCustomKeyboard() {
    overlayWindow?.isHidden = true
    restoreInsets()
    restoreSystemKeyboard()
  }

  private func suppressSystemKeyboard(for input: UIView) {
    guard suppressedInput?.input !== input else { return }
    restoreSystemKeyboard()
    suppressedInput = SuppressedInput(input: input, originalInputView: input.inputView)
    setInputView(EmptyInputView(), on: input)
  }

  private func restoreSystemKeyboard() {
    guard let suppressedInput else { return }
    self.suppressedInput = nil
    guard let input = suppressedInput.input else { return }
    setInputView(suppressedInput.originalInputView, on: input)
  }

  private func setInputView(_ inputView: UIView?, on input: UIView) {
    (input as? UITextField)?.inputView = inputView
    (input as? UITextView)?.inputView = inputView
    input.reloadInputViews()
  }

  /// The system keyboard isn't up, so SwiftUI's keyboard avoidance never runs. Reserve the
  /// space ourselves on every view controller in the presentation chain (sheets included).
  private func applyInsets(in window: UIWindow) {
    restoreInsets()
    let reserved = keyboardHeight - window.safeAreaInsets.bottom + window.safeAreaInsets.top
    var controller = window.rootViewController
    while let current = controller {
      insetBaselines.append(
        InsetBaseline(controller: current, original: current.additionalSafeAreaInsets))
      current.additionalSafeAreaInsets.bottom += reserved
      controller = current.presentedViewController
    }
  }

  private func restoreInsets() {
    for baseline in insetBaselines {
      baseline.controller?.additionalSafeAreaInsets = baseline.original
    }
    insetBaselines = []
  }

  private func showOverlay(over window: UIWindow) {
    guard let scene = window.windowScene else { return }
    if overlayWindow?.windowScene !== scene {
      overlayWindow?.isHidden = true
      overlayWindow = makeOverlayWindow(in: scene)
    }
    guard let overlayWindow else { return }
    overlayWindow.windowLevel = window.windowLevel + 1
    overlayWindow.transform = window.transform
    // Flipped, the window's top safe area (Dynamic Island) is at the bottom of the screen.
    keyboardBottomConstraint?.constant = -window.safeAreaInsets.top
    overlayWindow.isHidden = false
  }

  private func makeOverlayWindow(in scene: UIWindowScene) -> KeyboardOverlayWindow {
    let overlayWindow = KeyboardOverlayWindow(windowScene: scene)
    overlayWindow.backgroundColor = .clear
    let root = UIViewController()
    root.view.backgroundColor = .clear
    let host = UIHostingController(rootView: UpsideDownKeyboardView(model: keyboardModel))
    host.safeAreaRegions = []
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    root.addChild(host)
    root.view.addSubview(host.view)
    let bottom = host.view.bottomAnchor.constraint(equalTo: root.view.bottomAnchor)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
      host.view.heightAnchor.constraint(equalToConstant: keyboardHeight),
      bottom,
    ])
    host.didMove(toParent: root)
    overlayWindow.rootViewController = root
    overlayWindow.keyboardView = host.view
    keyboardBottomConstraint = bottom
    return overlayWindow
  }

  private func perform(_ command: UpsideDownKeyboardModel.Command) {
    guard let target, let input = target as? UITextInput else { return }
    switch command {
    case .insertText(let text):
      input.insertText(text)
    case .deleteBackward:
      input.deleteBackward()
    case .returnKey:
      returnKeyTapped(on: target, input: input)
    }
  }

  private func returnKeyTapped(on target: UIView, input: UITextInput) {
    guard let field = target as? UITextField else {
      input.insertText("\n")
      return
    }
    guard field.delegate?.textFieldShouldReturn?(field) ?? true else { return }
    field.sendActions(for: .editingDidEndOnExit)
  }
}

private struct SuppressedInput {
  weak var input: UIView?
  let originalInputView: UIView?
}

private struct InsetBaseline {
  weak var controller: UIViewController?
  let original: UIEdgeInsets
}

/// A zero-height input view: hides the system keyboard without drawing anything in its place.
private final class EmptyInputView: UIView {
  init() {
    super.init(frame: .zero)
    backgroundColor = .clear
    autoresizingMask = .flexibleWidth
  }

  required init?(coder: NSCoder) { nil }

  override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 0) }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

/// Never takes key status from the app, and only intercepts touches on the keyboard itself.
private final class KeyboardOverlayWindow: UIWindow {
  weak var keyboardView: UIView?

  override var canBecomeKey: Bool { false }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hit = super.hitTest(point, with: event), let keyboardView,
      hit.isDescendant(of: keyboardView)
    else { return nil }
    return hit
  }
}
