//
//  UpsideDownKeyboardView.swift
//  PlayolaRadio
//

import SwiftUI
import UIKit

/// Keys are drawn at the model's frames, and a single touch surface hands every touch to the
/// model, so where a key is drawn and where it is hit can never drift apart.
struct UpsideDownKeyboardView: View {
  let model: UpsideDownKeyboardModel

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      ZStack(alignment: .topLeading) {
        ForEach(model.placedKeys(keyboardWidth: width)) { placed in
          key(placed)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .overlay {
        KeyboardTouchSurface(
          touchesChanged: { model.keyboardTouchesChanged(at: $0, keyboardWidth: width) },
          touchesEnded: { model.keyboardTouchesEnded(at: $0, keyboardWidth: width) }
        )
        .accessibilityHidden(true)
      }
    }
    .background(Color.playolaSurfaceSection)
  }

  private func key(_ placed: UpsideDownKeyboardModel.PlacedKey) -> some View {
    Text(placed.key.label)
      .font(.custom(FontNames.Inter_500_Medium, fixedSize: 18))
      .foregroundStyle(.white)
      .frame(width: placed.frame.width, height: placed.frame.height)
      .background(Color.playolaSurfaceControl, in: RoundedRectangle(cornerRadius: 8))
      .opacity(model.keyOpacity(placed))
      .offset(x: placed.frame.minX, y: placed.frame.minY)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(placed.key.accessibilityLabel)
      .accessibilityAddTraits([.isButton, .isKeyboardKey])
      .accessibilityAction { model.keyTapped(placed.key.action) }
  }
}

/// UIKit reports each touch's location exactly, including when the window is rotated, and
/// tracks several fingers at once for fast two-thumb typing.
private struct KeyboardTouchSurface: UIViewRepresentable {
  let touchesChanged: ([CGPoint]) -> Void
  let touchesEnded: ([CGPoint]) -> Void

  func makeUIView(context: Context) -> TouchSurfaceView {
    let view = TouchSurfaceView()
    view.isMultipleTouchEnabled = true
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ view: TouchSurfaceView, context: Context) {
    view.touchesChanged = touchesChanged
    view.touchesEnded = touchesEnded
  }
}

private final class TouchSurfaceView: UIView {
  var touchesChanged: ([CGPoint]) -> Void = { _ in }
  var touchesEnded: ([CGPoint]) -> Void = { _ in }
  private var activeTouches: [UITouch] = []

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    activeTouches.append(contentsOf: touches)
    reportActiveTouches()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    reportActiveTouches()
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    let ended = activeTouches.filter(touches.contains)
    activeTouches.removeAll(where: touches.contains)
    touchesEnded(ended.map { $0.location(in: self) })
    reportActiveTouches()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    activeTouches.removeAll(where: touches.contains)
    reportActiveTouches()
  }

  private func reportActiveTouches() {
    touchesChanged(activeTouches.map { $0.location(in: self) })
  }
}
