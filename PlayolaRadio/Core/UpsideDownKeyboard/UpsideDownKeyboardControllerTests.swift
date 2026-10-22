//
//  UpsideDownKeyboardControllerTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import SwiftUI
import Testing
import UIKit

@testable import PlayolaRadio

@Suite(.serialized, .freshSharedState)
@MainActor
struct UpsideDownKeyboardControllerTests {
  struct Visibility: Equatable {
    let isModeEnabled: Bool
    let isWindowUpsideDown: Bool
    let isEditing: Bool
  }

  @Test
  func testCustomKeyboardShowsOnlyWhenModeEnabledWindowFlippedAndEditing() throws {
    var showingCustomKeyboard: [Visibility] = []
    var suppressingSystemKeyboard: [Visibility] = []

    for isModeEnabled in [false, true] {
      for isWindowUpsideDown in [false, true] {
        for isEditing in [false, true] {
          let controller = UpsideDownKeyboardController()
          let (window, field) = try makeWindowWithTextField()
          window.transform = isWindowUpsideDown ? upsideDown : .identity
          controller.setUpsideDownModeEnabled(isModeEnabled)
          if isEditing { controller.editingBegan(field) }

          let visibility = Visibility(
            isModeEnabled: isModeEnabled,
            isWindowUpsideDown: isWindowUpsideDown,
            isEditing: isEditing
          )
          if controller.isShowingCustomKeyboard { showingCustomKeyboard.append(visibility) }
          if field.inputView != nil { suppressingSystemKeyboard.append(visibility) }
          controller.setUpsideDownModeEnabled(false)
        }
      }
    }

    let onlyVisibleState = [
      Visibility(isModeEnabled: true, isWindowUpsideDown: true, isEditing: true)
    ]
    expectNoDifference(showingCustomKeyboard, onlyVisibleState)
    expectNoDifference(suppressingSystemKeyboard, onlyVisibleState)
  }

  @Test
  func testFlipDuringEditingShowsCustomKeyboard() throws {
    let controller = UpsideDownKeyboardController()
    let (window, field) = try makeWindowWithTextField()
    controller.editingBegan(field)
    #expect(controller.isShowingCustomKeyboard == false)

    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)

    #expect(controller.isShowingCustomKeyboard)
    #expect(field.inputView != nil)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testUnflipDuringEditingRestoresOriginalInputView() throws {
    let controller = UpsideDownKeyboardController()
    let (window, field) = try makeWindowWithTextField()
    let originalInputView = UIView()
    field.inputView = originalInputView
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    controller.editingBegan(field)
    #expect(field.inputView !== originalInputView)

    controller.setUpsideDownModeEnabled(false)

    #expect(controller.isShowingCustomKeyboard == false)
    #expect(field.inputView === originalInputView)
  }

  @Test
  func testEndingEditingHidesKeyboardAndRestoresInsets() throws {
    let controller = UpsideDownKeyboardController()
    let (window, field) = try makeWindowWithTextField()
    let root = try #require(window.rootViewController)
    root.additionalSafeAreaInsets.bottom = 5
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    controller.editingBegan(field)
    let keyboardClearance = 260 - window.safeAreaInsets.bottom + window.safeAreaInsets.top
    expectNoDifference(root.additionalSafeAreaInsets.bottom, 5 + keyboardClearance)

    controller.editingEnded(field)

    #expect(controller.isShowingCustomKeyboard == false)
    #expect(field.inputView == nil)
    expectNoDifference(root.additionalSafeAreaInsets.bottom, 5)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testEndingPreviousResponderDoesNotHideNewResponderKeyboard() throws {
    let controller = UpsideDownKeyboardController()
    let (window, firstField) = try makeWindowWithTextField()
    let secondField = UITextField()
    window.rootViewController?.view.addSubview(secondField)
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)

    controller.editingBegan(firstField)
    controller.editingBegan(secondField)
    controller.editingEnded(firstField)

    #expect(controller.isShowingCustomKeyboard)
    #expect(firstField.inputView == nil)
    #expect(secondField.inputView != nil)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testSheetDismissalRestoresAllModifiedInsets() throws {
    let controller = UpsideDownKeyboardController()
    let (window, field) = try makeWindowWithTextField()
    let root = try #require(window.rootViewController)
    let sheet = UIViewController()
    root.present(sheet, animated: false)
    try #require(root.presentedViewController === sheet)
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    controller.editingBegan(field)
    #expect(sheet.additionalSafeAreaInsets.bottom > 0)

    sheet.dismiss(animated: false)
    controller.editingEnded(field)

    expectNoDifference(root.additionalSafeAreaInsets.bottom, 0)
    expectNoDifference(sheet.additionalSafeAreaInsets.bottom, 0)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testKeyTapsEditTheFocusedTextView() throws {
    let controller = UpsideDownKeyboardController()
    let (window, _) = try makeWindowWithTextField()
    let textView = UITextView()
    window.rootViewController?.view.addSubview(textView)
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    controller.editingBegan(textView)

    controller.keyboardModel.keyTapped(.character("h"))
    controller.keyboardModel.keyTapped(.character("i"))
    controller.keyboardModel.keyTapped(.space)
    controller.keyboardModel.keyTapped(.delete)
    controller.keyboardModel.keyTapped(.returnKey)

    expectNoDifference(textView.text, "Hi\n")
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testReturnKeyOnTextFieldSubmits() throws {
    let controller = UpsideDownKeyboardController()
    let (window, field) = try makeWindowWithTextField()
    var didSubmit = false
    field.addAction(UIAction { _ in didSubmit = true }, for: .editingDidEndOnExit)
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    controller.editingBegan(field)

    controller.keyboardModel.keyTapped(.returnKey)

    #expect(didSubmit)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testStartedControllerFollowsRealFirstResponderChanges() async throws {
    let controller = UpsideDownKeyboardController()
    controller.start()
    await Task.megaYield()
    let (window, field) = try makeWindowWithTextField()
    let restoreKeyWindow = makeKey(window)
    defer { restoreKeyWindow() }
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)

    field.becomeFirstResponder()
    await Task.megaYield()
    #expect(controller.isShowingCustomKeyboard)

    field.resignFirstResponder()
    await Task.megaYield()
    #expect(controller.isShowingCustomKeyboard == false)
    #expect(field.inputView == nil)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testKeyTapsTypeIntoSwiftUITextFieldAndReturnSubmitsOnce() async throws {
    let controller = UpsideDownKeyboardController()
    controller.start()
    await Task.megaYield()
    let fields = SwiftUIFields()
    let (window, host) = try makeWindow(hosting: SwiftUIFieldsView(fields: fields))
    let restoreKeyWindow = makeKey(window)
    defer { restoreKeyWindow() }
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    let textField = try #require(firstSubview(of: UITextField.self, in: host.view))
    textField.becomeFirstResponder()
    await Task.megaYield()

    controller.keyboardModel.keyTapped(.character("h"))
    controller.keyboardModel.keyTapped(.character("i"))
    controller.keyboardModel.keyTapped(.returnKey)

    expectNoDifference(fields.searchText, "Hi")
    expectNoDifference(fields.submitCount, 1)
    controller.setUpsideDownModeEnabled(false)
  }

  @Test
  func testKeyTapsTypeIntoSwiftUITextEditor() async throws {
    let controller = UpsideDownKeyboardController()
    controller.start()
    await Task.megaYield()
    let fields = SwiftUIFields()
    let (window, host) = try makeWindow(hosting: SwiftUIFieldsView(fields: fields))
    let restoreKeyWindow = makeKey(window)
    defer { restoreKeyWindow() }
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)
    let textView = try #require(firstSubview(of: UITextView.self, in: host.view))
    textView.becomeFirstResponder()
    await Task.megaYield()

    controller.keyboardModel.keyTapped(.character("h"))
    controller.keyboardModel.keyTapped(.returnKey)
    controller.keyboardModel.keyTapped(.character("i"))

    expectNoDifference(fields.message, "H\ni")
    controller.setUpsideDownModeEnabled(false)
  }

  // MARK: - Helpers

  private let upsideDown = CGAffineTransform(rotationAngle: .pi)

  private func makeWindowWithTextField() throws -> (UIWindow, UITextField) {
    let (window, root) = try makeWindow(root: UIViewController())
    let field = UITextField()
    root.view.addSubview(field)
    return (window, field)
  }

  private func makeWindow(hosting view: some View) throws -> (UIWindow, UIViewController) {
    let (window, host) = try makeWindow(root: UIHostingController(rootView: view))
    host.view.layoutIfNeeded()
    return (window, host)
  }

  private func makeWindow<Root: UIViewController>(root: Root) throws -> (UIWindow, Root) {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let window = UIWindow(windowScene: scene)
    window.rootViewController = root
    window.isHidden = false
    return (window, root)
  }

  private func makeKey(_ window: UIWindow) -> () -> Void {
    let previousKeyWindow = window.windowScene?.keyWindow
    window.makeKey()
    return { previousKeyWindow?.makeKey() }
  }

  private func firstSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
    if let match = view as? T { return match }
    return view.subviews.lazy.compactMap { firstSubview(of: type, in: $0) }.first
  }
}

@MainActor
@Observable
private final class SwiftUIFields {
  var searchText = ""
  var submitCount = 0
  var message = ""
}

private struct SwiftUIFieldsView: View {
  @Bindable var fields: SwiftUIFields

  var body: some View {
    VStack {
      TextField("Search", text: $fields.searchText)
        .onSubmit { fields.submitCount += 1 }
      TextEditor(text: $fields.message)
        .frame(height: 100)
    }
  }
}
