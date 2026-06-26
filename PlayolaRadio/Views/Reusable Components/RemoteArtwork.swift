//
//  RemoteArtwork.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/26/26.
//

import SDWebImage
import UIKit

/// Helpers for displaying remote artwork without ballooning graphics memory.
enum RemoteArtwork {
  /// SDWebImage `context` that decodes a remote image down to its on-screen
  /// pixel size (display points × screen scale) instead of the full source
  /// resolution. Pass to `WebImage(url:context:)` so large source artwork is
  /// not kept in memory at full size.
  ///
  /// `imagePreserveAspectRatio` is set explicitly so a non-square source is
  /// scaled to fit the box (never stretched to it); the existing
  /// `.aspectRatio`/`.scaledToFill` modifier at each call site then handles the
  /// final crop, keeping artwork the same shape it was before downsampling.
  static func downsampleContext(
    _ displaySize: CGSize,
    scale: CGFloat = UIScreen.main.scale
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
