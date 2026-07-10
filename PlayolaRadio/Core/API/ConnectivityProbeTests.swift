//
//  ConnectivityProbeTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct ConnectivityProbeTests {

  // MARK: - diagnose

  @Test
  func tls13AndTls12SuccessIsHealthy() {
    let result = ConnectivityProbeResult(
      apiTLS13: .success, apiTLS12: .success, apiHTTP3: .failure, controlHost: .failure)
    #expect(ConnectivityProbe.diagnose(result) == .healthy)
  }

  @Test
  func tls13SuccessButCappedTls12FailureIsCappedPathBroken() {
    // Real requests ride the capped 1.2 path, so 1.3-works-but-1.2-fails means the cap itself
    // is breaking this network — must not be hidden under `.healthy`.
    let result = ConnectivityProbeResult(
      apiTLS13: .success, apiTLS12: .failure, apiHTTP3: .success, controlHost: .success)
    #expect(ConnectivityProbe.diagnose(result) == .cappedPathBroken)
  }

  @Test
  func tls13FailsButTls12WorksIsClientHelloDrop() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .success, apiHTTP3: .failure, controlHost: .failure)
    #expect(ConnectivityProbe.diagnose(result) == .clientHelloDrop)
  }

  @Test
  func tcpFailsButHttp3WorksIsHttp3Rescues() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .failure, apiHTTP3: .success, controlHost: .failure)
    #expect(ConnectivityProbe.diagnose(result) == .http3Rescues)
  }

  @Test
  func http3FellBackDoesNotCountAsRescue() {
    // A success that silently fell back to TCP/HTTP-2 is NOT an HTTP/3 win, so with every
    // real API transport failing and the control up, this is host filtering.
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .failure, apiHTTP3: .fellBack, controlHost: .success)
    #expect(ConnectivityProbe.diagnose(result) == .hostFiltered)
  }

  @Test
  func allApiTransportsFailButControlWorksIsHostFiltered() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .failure, apiHTTP3: .failure, controlHost: .success)
    #expect(ConnectivityProbe.diagnose(result) == .hostFiltered)
  }

  @Test
  func everythingFailsIncludingControlIsNoConnectivity() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .failure, apiHTTP3: .failure, controlHost: .failure)
    #expect(ConnectivityProbe.diagnose(result) == .noConnectivity)
  }

  @Test
  func skippedControlWithFailingApiIsIndeterminate() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .failure, apiHTTP3: .failure, controlHost: .skipped)
    #expect(ConnectivityProbe.diagnose(result) == .indeterminate)
  }

  // MARK: - tags

  @Test
  func tagsCarryEveryTransportAndDiagnosis() {
    let result = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .success, apiHTTP3: .fellBack, controlHost: .success)
    expectNoDifference(
      ConnectivityProbe.tags(for: result),
      [
        "tls13_probe_outcome": "failure",
        "probe_api_tls13": "failure",
        "probe_api_tls12": "success",
        "probe_api_http3": "fellBack",
        "probe_control": "success",
        "probe_diagnosis": "clientHelloDrop",
      ])
  }

  @Test
  func tls13ProbeOutcomeStaysBackwardCompatibleWithTheOldProbe() {
    // The legacy Sentry trend groups on `tls13_probe_outcome` = success/failure of the
    // uncapped TLS 1.3 probe. That mapping must not drift.
    let success = ConnectivityProbeResult(
      apiTLS13: .success, apiTLS12: .success, apiHTTP3: .success, controlHost: .success)
    #expect(ConnectivityProbe.tags(for: success)["tls13_probe_outcome"] == "success")

    let failure = ConnectivityProbeResult(
      apiTLS13: .failure, apiTLS12: .success, apiHTTP3: .success, controlHost: .success)
    #expect(ConnectivityProbe.tags(for: failure)["tls13_probe_outcome"] == "failure")
  }
}
