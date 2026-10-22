//
//  UIImageCacheTests.swift
//  PlayolaRadio
//

import Foundation
import Testing
import UIKit

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct UIImageCacheTests {
  private func cacheLargePNG(at url: URL) throws {
    let size = CGSize(width: 2000, height: 1000)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let png = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
      UIColor.red.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
    let response = try #require(
      HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    URLCache.shared.storeCachedResponse(
      CachedURLResponse(response: response, data: png), for: URLRequest(url: url))
  }

  @Test
  func imageWithMaxPixelSizeIsDownsampled() async throws {
    let url = try #require(URL(string: "https://example.com/\(UUID().uuidString).png"))
    try cacheLargePNG(at: url)

    let image = await UIImage.image(from: url, maxPixelSize: 600)

    let size = try #require(image).size
    #expect(max(size.width, size.height) == 600)
  }

  @Test
  func imageWithoutMaxPixelSizeKeepsFullResolution() async throws {
    let url = try #require(URL(string: "https://example.com/\(UUID().uuidString).png"))
    try cacheLargePNG(at: url)

    let image = await UIImage.image(from: url)

    let size = try #require(image).size
    #expect(size.width == 2000)
  }
}
