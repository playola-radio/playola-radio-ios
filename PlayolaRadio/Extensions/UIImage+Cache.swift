//
//  UIImage+Cache.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/13/24.
//

import UIKit

extension UIImage {
  /// With `maxPixelSize`, the bitmap is decoded as a thumbnail no larger than that on
  /// its long edge instead of at full resolution.
  static func image(from url: URL?, maxPixelSize: CGFloat? = nil) async -> UIImage? {
    guard let url else { return nil }

    let cache = URLCache.shared
    let request = URLRequest(url: url)

    if let data = cache.cachedResponse(for: request)?.data,
      let image = decode(data, maxPixelSize: maxPixelSize)
    {
      return image
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
        200...299 ~= httpResponse.statusCode,
        let image = decode(data, maxPixelSize: maxPixelSize)
      else {
        return nil
      }

      let cachedData = CachedURLResponse(response: httpResponse, data: data)
      cache.storeCachedResponse(cachedData, for: request)
      return image
    } catch {
      return nil
    }
  }

  private static func decode(_ data: Data, maxPixelSize: CGFloat?) -> UIImage? {
    guard let maxPixelSize else { return UIImage(data: data) }
    return CarPlayImageLoader.downsampledImage(from: data, maxPixelSize: maxPixelSize)
  }
}
