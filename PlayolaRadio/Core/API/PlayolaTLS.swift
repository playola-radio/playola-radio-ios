//
//  PlayolaTLS.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/10/26.
//

import Alamofire
import Foundation

/// Single source of truth for the app's first-party network transport policy.
///
/// Some listeners sit behind networks that interfere with TCP connections to `*.playola.fm`
/// specifically (host/SNI-targeted resets, SSL-inspection middleboxes) while leaving UDP/QUIC
/// alone. The earlier mitigation capped URLSession to TLS 1.2 to shrink the iOS 26 post-quantum
/// ClientHello — but that is still TCP, so it never helped these users (Sentry `tls13_probe`
/// diagnosis `http3Rescues`: both TLS 1.2 and TLS 1.3 over TCP fail while HTTP/3 succeeds).
///
/// We now prefer HTTP/3 (QUIC) on Playola API requests via `assumesHTTP3Capable`, which races
/// QUIC on the very first request and falls back to HTTP/2 over TCP automatically when QUIC is
/// unavailable. Only first-party Playola API hosts (which advertise `alt-svc: h3`) get the
/// hint; third-party hosts (e.g. S3 artwork) are untouched.
enum PlayolaTLS {
  /// First-party API hosts we own. All Playola API subdomains (`admin-api`,
  /// `admin-api-staging`, `production-api`, …) are on Cloudflare and advertise `alt-svc: h3`,
  /// so match the whole `*.playola.fm` zone — this keeps staging/TestFlight able to exercise
  /// the mitigation, and future subdomains work automatically. Non-Playola hosts (e.g. S3
  /// artwork on `amazonaws.com`) are excluded; `assumesHTTP3Capable` falls back gracefully
  /// anyway, so an over-match would be harmless.
  static func isPlayolaAPIHost(_ host: String?) -> Bool {
    guard let host else { return false }
    return host == "playola.fm" || host.hasSuffix(".playola.fm")
  }

  /// Marks a request to a Playola API host as HTTP/3-preferring. No-op for other hosts.
  static func preferHTTP3IfPlayolaHost(_ request: inout URLRequest) {
    if isPlayolaAPIHost(request.url?.host) {
      request.assumesHTTP3Capable = true
    }
  }

  /// Alamofire interceptor that applies the HTTP/3 hint to every Playola API request issued on
  /// a `Session`. Attach to the shared `apiSession`.
  static let http3Interceptor = Adapter { urlRequest, _, completion in
    var request = urlRequest
    preferHTTP3IfPlayolaHost(&request)
    completion(.success(request))
  }

  /// Shared uncapped `URLSession` for FIRST-PARTY requests that do NOT go through Alamofire
  /// (e.g. the URL-stream listening-session reporter). Callers set the HTTP/3 hint per request
  /// via `preferHTTP3IfPlayolaHost`.
  static let sharedSession = URLSession(configuration: .default)

  /// Caps a configuration to TLS 1.2. Retained ONLY for `ConnectivityProbe`'s diagnostic
  /// TLS-1.2 measurement leg — production no longer caps TLS. Do NOT use for real requests.
  static func mitigated(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
    configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
    return configuration
  }
}
