//
//  UIImage+Cache.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/13/24.
//

import UIKit

extension UIImage {
  static func image(from url: URL?) async -> UIImage? {
    guard let url else { return nil }

    let cache = URLCache.shared
    let request = URLRequest(url: url)

    if let data = cache.cachedResponse(for: request)?.data, let image = UIImage(data: data) {
      return image
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
        200...299 ~= httpResponse.statusCode,
        let image = UIImage(data: data)
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
}
