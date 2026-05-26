//
//  PresetsCarousel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct PresetsCarousel: View {
  let displays: [PresetDisplayItem]
  let sectionTitle: String
  let emptyStateText: String
  let isEditing: Bool
  let onTilePlay: (PresetDisplayItem) async -> Void
  let onTileLongPress: (PresetDisplayItem) -> Void
  let onTileRemove: (PresetDisplayItem) async -> Void
  let onMove: (Int, Int) async -> Void
  let onEditDoneTapped: () -> Void

  @State private var dragState: PresetDragState?
  @State private var tileFrames: [String: CGRect] = [:]

  private static let presetTileWidth: CGFloat = 92
  private static let presetTileSpacing: CGFloat = 12
  private static let presetTileStride = presetTileWidth + presetTileSpacing
  private static let carouselCoordinateSpace = "presets-carousel"

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(sectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
        Spacer()
        if isEditing {
          Button {
            onEditDoneTapped()
          } label: {
            Text("Done")
              .font(.custom(FontNames.Inter_500_Medium, size: 14))
              .foregroundColor(.playolaRed)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)

      if displays.isEmpty {
        emptyState
      } else {
        tiles
      }
    }
  }

  private var emptyState: some View {
    HStack(spacing: 16) {
      Image(systemName: "star.fill")
        .font(.system(size: 24))
        .foregroundColor(Color(hex: "#FFD24A"))
      Text(emptyStateText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(Color(hex: "#AAAAAA"))
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(16)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
          Color(hex: "#333333"),
          style: StrokeStyle(lineWidth: 1, dash: [4])
        )
    )
    .padding(.horizontal, 16)
  }

  private var tiles: some View {
    let displayedDisplays = dragState?.displays ?? displays
    let idOrder = displayedDisplays.map(\.id)

    return ScrollView(.horizontal, showsIndicators: false) {
      ZStack(alignment: .topLeading) {
        HStack(spacing: Self.presetTileSpacing) {
          ForEach(displayedDisplays) { display in
            let tile = PresetTile(
              display: display,
              isEditing: isEditing,
              onTap: { await onTilePlay(display) },
              onLongPress: { onTileLongPress(display) },
              onRemoveTapped: { await onTileRemove(display) }
            )
            .opacity(dragState?.sourceId == display.id ? 0 : 1)
            .background(tileFrameReader(for: display.id))

            if isEditing && !display.isPending {
              tile.overlay {
                LongPressReorderRecognizer(
                  minimumDuration: 0.4,
                  maximumDistance: 10,
                  passthroughRect: CGRect(x: 0, y: 0, width: 50, height: 50),
                  onBegan: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    updateDrag(display, translation: .zero)
                  },
                  onChanged: { translation in
                    updateDrag(display, translation: translation)
                  },
                  onEnded: {
                    endDrag(display)
                  }
                )
              }
            } else {
              tile
            }
          }
        }
        .padding(.horizontal, 16)
        .animation(.smooth(duration: 0.25), value: idOrder)

        if let dragState,
          let display = displays.first(where: { $0.id == dragState.sourceId })
        {
          PresetTile(
            display: display,
            isEditing: isEditing,
            onTap: { await onTilePlay(display) },
            onLongPress: { onTileLongPress(display) },
            onRemoveTapped: { await onTileRemove(display) }
          )
          .position(dragState.overlayCenter)
          .zIndex(1)
          .allowsHitTesting(false)
        }
      }
      .coordinateSpace(name: Self.carouselCoordinateSpace)
    }
    .onPreferenceChange(PresetTileFramePreferenceKey.self) { frames in
      tileFrames = frames
    }
    .onChange(of: displays.map(\.id)) { _, newIds in
      guard let dragState else { return }
      if newIds == dragState.displays.map(\.id) {
        self.dragState = nil
      }
    }
    .onChange(of: isEditing) { _, newValue in
      if !newValue {
        dragState = nil
      }
    }
    .overlay(alignment: .trailing) {
      LinearGradient(
        colors: [Color.black.opacity(0), Color.black],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: 24)
      .allowsHitTesting(false)
    }
  }

  private func tileFrameReader(for id: String) -> some View {
    GeometryReader { proxy in
      Color.clear.preference(
        key: PresetTileFramePreferenceKey.self,
        value: [id: proxy.frame(in: .named(Self.carouselCoordinateSpace))]
      )
    }
  }

  private func updateDrag(
    _ display: PresetDisplayItem,
    translation: CGSize
  ) {
    guard isEditing, !display.isPending else { return }

    if dragState == nil {
      guard
        let sourceIndex = displays.firstIndex(where: { $0.id == display.id }),
        let sourceFrame = tileFrames[display.id]
      else { return }

      dragState = PresetDragState(
        sourceId: display.id,
        sourceIndex: sourceIndex,
        destinationIndex: sourceIndex,
        displays: displays,
        sourceCenter: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY),
        translation: .zero
      )
    }

    guard var state = dragState, state.sourceId == display.id else { return }

    state.translation = translation

    let currentDelta = state.destinationIndex - state.sourceIndex
    let progress = translation.width / Self.presetTileStride
    let bias: Double = 0.15
    let proposedDelta: Int
    if progress > Double(currentDelta) + 0.5 + bias {
      proposedDelta = currentDelta + 1
    } else if progress < Double(currentDelta) - 0.5 - bias {
      proposedDelta = currentDelta - 1
    } else {
      proposedDelta = currentDelta
    }

    let proposedIndex = state.sourceIndex + proposedDelta

    guard
      let destinationIndex = destinationIndex(for: proposedIndex),
      destinationIndex != state.destinationIndex,
      let currentIndex = state.displays.firstIndex(where: { $0.id == state.sourceId })
    else {
      dragState = state
      return
    }

    var reorderedDisplays = state.displays
    let movedDisplay = reorderedDisplays.remove(at: currentIndex)
    reorderedDisplays.insert(movedDisplay, at: destinationIndex)

    state.displays = reorderedDisplays
    state.destinationIndex = destinationIndex

    withAnimation(.smooth(duration: 0.25)) {
      dragState = state
    }
  }

  private func endDrag(_ display: PresetDisplayItem) {
    guard let state = dragState, state.sourceId == display.id else { return }

    dragState = nil

    guard state.sourceIndex != state.destinationIndex else { return }

    Task {
      await onMove(state.sourceIndex, state.destinationIndex)
    }
  }

  private func destinationIndex(for proposedIndex: Int) -> Int? {
    guard !displays.isEmpty else { return nil }

    let clampedIndex = min(max(proposedIndex, 0), displays.count - 1)
    guard !displays[clampedIndex].isPending else { return nil }

    return clampedIndex
  }
}

private struct PresetDragState {
  let sourceId: String
  let sourceIndex: Int
  var destinationIndex: Int
  var displays: [PresetDisplayItem]
  let sourceCenter: CGPoint
  var translation: CGSize

  var overlayCenter: CGPoint {
    CGPoint(
      x: sourceCenter.x + translation.width,
      y: sourceCenter.y + translation.height
    )
  }
}

private struct LongPressReorderRecognizer: UIViewRepresentable {
  let minimumDuration: TimeInterval
  let maximumDistance: CGFloat
  let passthroughRect: CGRect
  let onBegan: () -> Void
  let onChanged: (CGSize) -> Void
  let onEnded: () -> Void

  func makeUIView(context: Context) -> UIView {
    let view = PassthroughView()
    view.backgroundColor = .clear
    view.passthroughRect = passthroughRect

    let recognizer = UILongPressGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handle(_:))
    )
    recognizer.minimumPressDuration = minimumDuration
    recognizer.allowableMovement = maximumDistance
    recognizer.cancelsTouchesInView = false
    recognizer.delegate = context.coordinator

    view.addGestureRecognizer(recognizer)
    context.coordinator.view = view
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    context.coordinator.onBegan = onBegan
    context.coordinator.onChanged = onChanged
    context.coordinator.onEnded = onEnded
    (uiView as? PassthroughView)?.passthroughRect = passthroughRect
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onBegan: onBegan, onChanged: onChanged, onEnded: onEnded)
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    weak var view: UIView?
    var startPoint: CGPoint?
    var onBegan: () -> Void
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void

    init(
      onBegan: @escaping () -> Void,
      onChanged: @escaping (CGSize) -> Void,
      onEnded: @escaping () -> Void
    ) {
      self.onBegan = onBegan
      self.onChanged = onChanged
      self.onEnded = onEnded
    }

    @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
      guard let view else { return }
      let point = recognizer.location(in: view)

      switch recognizer.state {
      case .began:
        startPoint = point
        cancelEnclosingScrollPan(from: view)
        onBegan()
      case .changed:
        guard let startPoint else { return }
        onChanged(
          CGSize(
            width: point.x - startPoint.x,
            height: point.y - startPoint.y
          )
        )
      case .ended, .cancelled, .failed:
        startPoint = nil
        onEnded()
      default:
        break
      }
    }

    private func cancelEnclosingScrollPan(from view: UIView) {
      var current: UIView? = view.superview
      while let next = current {
        if let scroll = next as? UIScrollView {
          // Toggling isEnabled cancels the in-flight pan so the carousel
          // doesn't scroll while we drag a tile.
          scroll.panGestureRecognizer.isEnabled = false
          scroll.panGestureRecognizer.isEnabled = true
          return
        }
        current = next.superview
      }
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      // Allow simultaneous so the ScrollView's pan can also track the touch.
      // Once our long-press succeeds (.began), we cancel the pan manually.
      true
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      // The ScrollView's pan should NOT require us to fail — both track in parallel.
      false
    }
  }

  private final class PassthroughView: UIView {
    var passthroughRect: CGRect = .zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      guard bounds.contains(point) else { return nil }
      // Let touches in the passthroughRect (the X-badge area) fall through to
      // the SwiftUI Button underneath.
      if passthroughRect.contains(point) { return nil }
      // Otherwise claim the touch so the long-press recognizer can track it.
      // cancelsTouchesInView=false lets the ScrollView's pan also track,
      // so quick swipes still scroll.
      return self
    }
  }
}

private struct PresetTileFramePreferenceKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]

  static func reduce(
    value: inout [String: CGRect],
    nextValue: () -> [String: CGRect]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

#Preview("With Presets") {
  let stations = (0..<5).map { i in
    Station.mockWith(id: "s\(i)", name: "Station \(i)", curatorName: "Curator \(i)")
  }
  let items = stations.enumerated().map { idx, station in
    APIStationItem(sortOrder: idx, visibility: .visible, station: station, urlStation: nil)
  }
  let displays = items.enumerated().map { idx, item in
    PresetDisplayItem(id: "p\(idx)", stationItem: item, isPending: false)
  }
  return PresetsCarousel(
    displays: displays,
    sectionTitle: "Presets",
    emptyStateText: "Tap the ★ on any station to save it here.",
    isEditing: false,
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onTileRemove: { _ in },
    onMove: { _, _ in },
    onEditDoneTapped: {}
  )
  .padding(.vertical)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Empty") {
  PresetsCarousel(
    displays: [],
    sectionTitle: "Presets",
    emptyStateText: "Tap the ★ on any station to save it here.",
    isEditing: false,
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onTileRemove: { _ in },
    onMove: { _, _ in },
    onEditDoneTapped: {}
  )
  .padding(.vertical)
  .background(Color.black)
  .preferredColorScheme(.dark)
}
