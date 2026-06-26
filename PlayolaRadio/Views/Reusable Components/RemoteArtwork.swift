//
//  RemoteArtwork.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/26/26.
//

import CoreGraphics
import SDWebImage

/// Helpers for displaying remote artwork without ballooning graphics memory.
enum RemoteArtwork {
  /// SDWebImage `context` that decodes a remote image down to its on-screen
  /// pixel size (display points × screen scale) instead of the full source
  /// resolution. Pass to `WebImage(url:context:)` so large source artwork is
  /// not kept in memory at full size.
  ///
  /// Callers pass `scale` from `@Environment(\.displayScale)` so the decode
  /// matches the actual display the view is rendered on (and to avoid the
  /// deprecated `UIScreen.main`).
  ///
  /// `imagePreserveAspectRatio` is set explicitly so a non-square source is
  /// scaled to fit the box (never stretched to it); the existing
  /// `.aspectRatio`/`.scaledToFill` modifier at each call site then handles the
  /// final crop, keeping artwork the same shape it was before downsampling.
  static func downsampleContext(
    _ displaySize: CGSize,
    scale: CGFloat
  ) -> [SDWebImageContextOption: Any] {
    [
      .imageThumbnailPixelSize: CGSize(
        width: displaySize.width * scale,
        height: displaySize.height * scale
      ),
      .imagePreserveAspectRatio: true,
    ]
  }
}
