//
//  CPListItem+InitWithRemoteUrl.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/20/25.
//
@preconcurrency import CarPlay
import Foundation
import ImageIO
import UIKit

// MARK: - Image Loader Actor

/// Thread-safe image loader for CarPlay
actor CarPlayImageLoader {
  static let shared = CarPlayImageLoader()

  private let cache = NSCache<NSURL, UIImage>()
  private var activeTasks: [URL: Task<UIImage?, Never>] = [:]

  /// Max pixel size for downsampled CarPlay list thumbnails. CarPlay rows show
  /// artwork at roughly 44–60pt; 200px covers that comfortably on high-scale
  /// displays while keeping the decoded bitmap tiny.
  private static let maxThumbnailPixelSize: CGFloat = 200

  private let urlSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 10.0
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.urlCache = URLCache(
      memoryCapacity: 10 * 1024 * 1024,  // 10 MB
      diskCapacity: 50 * 1024 * 1024,  // 50 MB
      diskPath: "carplay_images"
    )
    return URLSession(configuration: config)
  }()

  init() {
    cache.countLimit = 100
    cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
  }

  func loadImage(from url: URL) async -> UIImage? {
    // Check cache first
    if let cachedImage = cache.object(forKey: url as NSURL) {
      return cachedImage
    }

    // Check if there's already a task loading this URL
    if let existingTask = activeTasks[url] {
      return await existingTask.value
    }

    // Create new loading task
    let task = Task { () -> UIImage? in
      do {
        let (data, _) = try await urlSession.data(from: url)
        // Downsample to CarPlay's small thumbnail size. Station artwork is
        // full-resolution (often >1000px); decoding it whole is slow and holds
        // multi-MB bitmaps in memory just to draw a ~60pt row image. A thumbnail
        // decode is far faster and tiny.
        guard
          let image = Self.downsampledImage(
            from: data, maxPixelSize: Self.maxThumbnailPixelSize)
        else {
          print("CarPlay image loading failed: Invalid image data from \(url)")
          return nil
        }

        // Cache the image
        cache.setObject(image, forKey: url as NSURL)
        return image
      } catch {
        if (error as NSError).code != NSURLErrorCancelled {
          print("CarPlay image loading error for \(url): \(error.localizedDescription)")
        }
        return nil
      }
    }

    // Store the task
    activeTasks[url] = task

    // Clean up when done
    let result = await task.value
    activeTasks[url] = nil

    return result
  }

  func cancelLoading(for url: URL) {
    activeTasks[url]?.cancel()
    activeTasks[url] = nil
  }

  /// Decodes `data` directly to a thumbnail no larger than `maxPixelSize` on its
  /// long edge via ImageIO, without ever materializing the full-resolution bitmap.
  static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
      return nil
    }
    let options =
      [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      return nil
    }
    return UIImage(cgImage: cgImage)
  }

  func clearCache() {
    cache.removeAllObjects()
    for task in activeTasks.values {
      task.cancel()
    }
    activeTasks.removeAll()
  }
}

// MARK: - CPListItem Extension

extension CPListItem {
  private static let identifierUserInfoKey = "CPListItem.Identifier"
  private static let imageURLUserInfoKey = "CPListItem.ImageURL"

  public convenience init(
    text: String?,
    detailText: String?,
    remoteImageUrl: URL?,
    placeholder: UIImage?
  ) {
    self.init(text: text, detailText: detailText, image: placeholder)

    guard let remoteImageUrl else { return }

    // Store URL in userInfo for later cancellation
    var info = (userInfo as? [String: Any]) ?? [:]
    info[Self.imageURLUserInfoKey] = remoteImageUrl
    userInfo = info

    // Load image asynchronously
    Task { @MainActor in
      if let image = await CarPlayImageLoader.shared.loadImage(from: remoteImageUrl) {
        self.setImage(image)
      }
    }
  }

  // MARK: - Identifier Support

  var identifier: String? {
    (userInfo as? [String: Any])?[Self.identifierUserInfoKey] as? String
  }

  // MARK: - Image Management

  /// Cancel image loading for this item
  public func cancelImageLoading() {
    guard let url = (userInfo as? [String: Any])?[Self.imageURLUserInfoKey] as? URL else { return }

    Task {
      await CarPlayImageLoader.shared.cancelLoading(for: url)
    }
  }
}

// MARK: - Cache Management

extension CPListItem {
  /// Clear all cached images
  public static func clearImageCache() {
    Task {
      await CarPlayImageLoader.shared.clearCache()
    }
  }
}
