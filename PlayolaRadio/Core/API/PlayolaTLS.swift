//
//  PlayolaTLS.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/10/26.
//

import Foundation

/// Single source of truth for the TEMPORARY iOS 26 TLS mitigation.
///
/// On iOS 26, URLSession sends a TLS 1.3 ClientHello that includes the X25519MLKEM768
/// post-quantum hybrid key share (~1.1 KB). It spans two TCP segments, and some middleboxes
/// (antivirus SSL inspection, parental-control routers, captive portals, etc.) drop the
/// oversized ClientHello and surface it as NSURLErrorSecureConnectionFailed (-1200) — every
/// request fails on those networks. Capping the session to TLS 1.2 keeps the ClientHello small
/// enough to pass.
///
/// Every first-party URLSession / Alamofire session in the app routes through here so the
/// policy lives in exactly one place. When we later make this adaptive (try 1.3, fall back to
/// 1.2) or add HTTP/3, this is the seam to change.
///
/// REVERT WHEN: Apple ships an iOS 26 fix (watch the `tls13_probe` Sentry trend) OR exposes a
/// supported opt-out for the post-quantum hybrid key share so we can keep TLS 1.3.
enum PlayolaTLS {
  /// Applies the TLS 1.2 cap to a configuration and returns it. Callers pass whatever base
  /// configuration they need (default, Alamofire's default, or one with custom caching).
  static func mitigated(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
    configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
    return configuration
  }

  /// Shared TLS-mitigated `URLSession` for FIRST-PARTY requests that do NOT go through
  /// Alamofire (e.g. the listening-session reporter). Deliberately not used for remote artwork
  /// loaders: those can hit third-party / TLS-1.3-only image hosts, where capping to 1.2 would
  /// break loads on the healthy majority of networks for no real gain (artwork is cosmetic and
  /// the main artwork path is SDWebImage, which is uncapped anyway).
  static let sharedSession = URLSession(configuration: mitigated(.default))
}
