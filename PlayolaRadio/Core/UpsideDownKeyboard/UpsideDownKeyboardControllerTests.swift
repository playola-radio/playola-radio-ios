//
//  UpsideDownKeyboardControllerTests.swift
//  PlayolaRadio
//

import CustomDump
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

  // MARK: - Helpers

  private let upsideDown = CGAffineTransform(rotationAngle: .pi)

  private func makeWindowWithTextField() throws -> (UIWindow, UITextField) {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let window = UIWindow(windowScene: scene)
    let root = UIViewController()
    window.rootViewController = root
    window.isHidden = false
    let field = UITextField()
    root.view.addSubview(field)
    return (window, field)
  }
}
