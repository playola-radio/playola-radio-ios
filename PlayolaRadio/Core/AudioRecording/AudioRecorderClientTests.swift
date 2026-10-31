//
//  AudioRecorderClientTests.swift
//  PlayolaRadio
//

import AVFoundation
import CustomDump
import Dependencies
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AudioRecorderClientTests {
  @Test
  func prepareForRecordingDefersSessionConfigToCoordinator() async throws {
    let spy = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spy)

    try await withDependencies {
      $0.audioSessionCoordinator = coordinator
    } operation: {
      let client = AudioRecorderClient.liveValue
      try await client.prepareForRecording()
    }

    // The recorder must switch the session to .playAndRecord through the
    // coordinator (the single session owner) rather than touching
    // AVAudioSession directly.
    #expect(spy.categories.last?.category == .playAndRecord)
    #expect(spy.activations.last == true)
  }

  @Test
  func testBuiltInMicIsNotExternal() {
    expectNoDifference(AudioRecorderClient.isExternalMicrophone(inputs: [.builtInMic]), false)
  }

  @Test
  func testNoInputsIsNotExternal() {
    expectNoDifference(AudioRecorderClient.isExternalMicrophone(inputs: []), false)
  }

  @Test(arguments: [
    AVAudioSession.Port.headsetMic, .bluetoothHFP, .usbAudio, .carAudio,
  ])
  func testHeadsetBluetoothUSBAndCarInputsAreExternal(port: AVAudioSession.Port) {
    expectNoDifference(AudioRecorderClient.isExternalMicrophone(inputs: [port]), true)
  }
}
