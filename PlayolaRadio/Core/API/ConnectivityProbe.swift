//
//  ConnectivityProbe.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/10/26.
//

import Dependencies
import Foundation
import Sharing

// MARK: - Pure model + diagnosis (unit-tested)

/// Outcome of a single probe request.
enum ProbeOutcome: String, Sendable, Equatable {
  case success
  case failure
  /// The request succeeded but negotiated a different protocol than intended
  /// (e.g. an HTTP/3 probe that fell back to HTTP/2 over TCP). Only meaningful
  /// for the HTTP/3 probe, where it means "QUIC/UDP did not actually carry this".
  case fellBack
  case skipped
}

/// One connectivity probe run: our API host reached four ways, plus a control host.
///
/// The point is to distinguish the competing failure theories for the iOS 26
/// NSURLErrorSecureConnectionFailed reports, per network:
/// - `apiTLS13`: uncapped, forced TLS 1.3, HTTP/2 — the original probe. Fails when a
///   middlebox drops the oversized post-quantum ClientHello.
/// - `apiTLS12`: the production profile (capped to TLS 1.2), HTTP/2 — does the shipped
///   mitigation actually get through?
/// - `apiHTTP3`: forced TLS 1.3 with HTTP/3 requested — does routing over QUIC/UDP survive
///   where TCP does not? (verified via the negotiated protocol, not just success)
/// - `controlHost`: the production profile to a DIFFERENT host on the same CDN (Cloudflare).
///   Succeeding here while every API transport fails implicates domain/SNI filtering of us
///   specifically, not a broken network.
struct ConnectivityProbeResult: Sendable, Equatable {
  var apiTLS13: ProbeOutcome
  var apiTLS12: ProbeOutcome
  var apiHTTP3: ProbeOutcome
  var controlHost: ProbeOutcome
}

/// The network condition inferred from a probe result. This is the signal that tells us
/// which remediation (keep the cap / enable HTTP/3 / nothing client-side) actually helps.
enum ProbeDiagnosis: String, Sendable, Equatable {
  /// TLS 1.3 to our API works — no iOS 26 problem on this network.
  case healthy
  /// TLS 1.3 works but the production profile (capped to TLS 1.2) fails — the global cap is
  /// itself breaking this network. This is the signal that the cap should become adaptive /
  /// be dropped, since real requests use the capped path.
  case cappedPathBroken
  /// TLS 1.3 fails but TLS 1.2 works — the classic oversized-ClientHello drop. The shipped
  /// global cap is the fix.
  case clientHelloDrop
  /// TLS 1.2 also fails but HTTP/3 works — enabling HTTP/3 for real requests would help.
  case http3Rescues
  /// Every transport to our API fails but the control host (same CDN, different domain)
  /// works — points to domain/SNI filtering of playola specifically. No client TLS change helps.
  case hostFiltered
  /// The control host also fails — broader connectivity problem, not specific to us.
  case noConnectivity
  /// Not enough signal to classify (e.g. the control probe was skipped).
  case indeterminate
}

enum ConnectivityProbe {
  /// Classify a probe result. Order matters: the first transport that reaches our API wins,
  /// so `healthy` beats `clientHelloDrop` beats `http3Rescues`. Only when every API transport
  /// fails do we consult the control host to separate "it's just us" from "network is down".
  static func diagnose(_ result: ConnectivityProbeResult) -> ProbeDiagnosis {
    if result.apiTLS13 == .success {
      // Real requests ride the capped TLS 1.2 path; if 1.3 works but 1.2 doesn't, the cap
      // itself is the problem here — surface it instead of hiding it under `.healthy`.
      return result.apiTLS12 == .failure ? .cappedPathBroken : .healthy
    }
    if result.apiTLS12 == .success { return .clientHelloDrop }
    if result.apiHTTP3 == .success { return .http3Rescues }

    switch result.controlHost {
    case .success: return .hostFiltered
    case .failure: return .noConnectivity
    case .fellBack, .skipped: return .indeterminate
    }
  }

  /// Sentry tags for a probe run. `tls13_probe_outcome` is kept byte-compatible with the
  /// original probe so the existing 30-day trend query keeps working; the rest is new signal.
  static func tags(for result: ConnectivityProbeResult) -> [String: String] {
    [
      "tls13_probe_outcome": result.apiTLS13 == .success ? "success" : "failure",
      "probe_api_tls13": result.apiTLS13.rawValue,
      "probe_api_tls12": result.apiTLS12.rawValue,
      "probe_api_http3": result.apiHTTP3.rawValue,
      "probe_control": result.controlHost.rawValue,
      "probe_diagnosis": diagnose(result).rawValue,
    ]
  }
}

// MARK: - Network runner (thin I/O, not unit-tested)

/// Fires once per build per device from app launch. Runs the four probes and reports a single
/// `tls13_probe` Sentry event whose tags carry the per-transport outcomes and diagnosis.
/// Aggregating `probe_diagnosis` across users is what lets us choose the next remediation and,
/// eventually, revert the global TLS 1.2 cap.
func runConnectivityProbe() async {
  @Shared(.tls13ProbeLastSentBuild) var lastSentBuild: String?
  guard let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
    lastSentBuild != currentBuild
  else { return }

  let result = await ConnectivityProbe.run(baseURL: Config.shared.baseUrl)

  @Dependency(\.errorReporting) var errorReporting
  await errorReporting.reportMessage("tls13_probe", ConnectivityProbe.tags(for: result))
  $lastSentBuild.withLock { $0 = currentBuild }
}

extension ConnectivityProbe {
  /// A small unauthenticated endpoint, cheap to hit repeatedly.
  private static let apiProbePath = "/v1/app-version-requirements"
  /// Different domain, same CDN (Cloudflare) as our API, so a success here isolates
  /// domain/SNI filtering from CDN-wide or network-wide blocking.
  private static let controlURL = URL(string: "https://www.cloudflare.com/cdn-cgi/trace")!

  /// A `.default` configuration with all caching disabled so every probe performs a real
  /// network handshake. A cached `/v1/app-version-requirements` response would otherwise report
  /// `success` (or a `nil` negotiated protocol for the HTTP/3 probe) without measuring TLS/QUIC.
  private static func probeBaseConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.default
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  /// Forces TLS 1.3 exactly (both bounds pinned — leaving `max` at the default sentinel while
  /// bumping `min` to 1.3 yields an empty version window and a `NO_SUPPORTED_VERSIONS_ENABLED`
  /// config error instead of an actual network measurement).
  private static func forcedTLS13Configuration() -> URLSessionConfiguration {
    let config = probeBaseConfiguration()
    config.tlsMinimumSupportedProtocolVersion = .TLSv13
    config.tlsMaximumSupportedProtocolVersion = .TLSv13
    return config
  }

  /// Uncapped, forced to TLS 1.3 — the request fails if the network can't carry a 1.3 handshake.
  private static let tls13Session = URLSession(configuration: forcedTLS13Configuration())

  /// The exact production profile (capped to TLS 1.2, caching disabled for the probe). Used for
  /// the API 1.2 probe and the control host so they are apples-to-apples with real requests.
  private static let tls12Session = URLSession(
    configuration: PlayolaTLS.mitigated(probeBaseConfiguration()))

  /// Forced TLS 1.3, used with `assumesHTTP3Capable` requests to probe QUIC/UDP.
  private static let http3Session = URLSession(configuration: forcedTLS13Configuration())

  static func run(baseURL: URL) async -> ConnectivityProbeResult {
    let apiURL = baseURL.appendingPathComponent(apiProbePath)

    // Sequential (not concurrent) so probes to the same host don't share/coalesce a
    // connection and muddy the per-transport signal.
    let tls13 = await attempt(apiURL, session: tls13Session).outcome(expectingProtocol: nil)
    let tls12 = await attempt(apiURL, session: tls12Session).outcome(expectingProtocol: nil)
    let http3 = await attempt(apiURL, session: http3Session, assumesHTTP3: true)
      .outcome(expectingProtocol: "h3")
    let control = await attempt(controlURL, session: tls12Session).outcome(expectingProtocol: nil)

    return ConnectivityProbeResult(
      apiTLS13: tls13, apiTLS12: tls12, apiHTTP3: http3, controlHost: control)
  }

  private struct Attempt {
    var succeeded: Bool
    var negotiatedProtocol: String?

    /// Map a raw attempt to an outcome. When `expectingProtocol` is set (the HTTP/3 probe),
    /// a success that negotiated a different protocol counts as `fellBack`, not `success`.
    func outcome(expectingProtocol expected: String?) -> ProbeOutcome {
      guard succeeded else { return .failure }
      if let expected, negotiatedProtocol != expected { return .fellBack }
      return .success
    }
  }

  private static func attempt(
    _ url: URL,
    session: URLSession,
    assumesHTTP3: Bool = false
  ) async -> Attempt {
    var request = URLRequest(url: url)
    request.timeoutInterval = 10
    if assumesHTTP3 { request.assumesHTTP3Capable = true }

    let collector = ProbeMetricsCollector()
    do {
      let (_, response) = try await session.data(for: request, delegate: collector)
      let httpOK =
        (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
      // A cache hit is not a network measurement — reject it so we never report a transport as
      // reachable without an actual handshake.
      let ok = httpOK && !collector.servedFromCache
      return Attempt(succeeded: ok, negotiatedProtocol: collector.negotiatedProtocol)
    } catch {
      return Attempt(succeeded: false, negotiatedProtocol: collector.negotiatedProtocol)
    }
  }
}

/// Captures the negotiated network protocol ("h3" / "h2" / "http/1.1") for a task so the
/// HTTP/3 probe can tell a real QUIC success from a silent TCP fallback.
private final class ProbeMetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var storedProtocol: String?
  private var storedServedFromCache = false

  var negotiatedProtocol: String? {
    lock.lock()
    defer { lock.unlock() }
    return storedProtocol
  }

  /// True only when the response positively came from a local cache (not a network load).
  var servedFromCache: Bool {
    lock.lock()
    defer { lock.unlock() }
    return storedServedFromCache
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    let last = metrics.transactionMetrics.last
    lock.lock()
    storedProtocol = last?.networkProtocolName
    storedServedFromCache = last?.resourceFetchType == .localCache
    lock.unlock()
  }
}
