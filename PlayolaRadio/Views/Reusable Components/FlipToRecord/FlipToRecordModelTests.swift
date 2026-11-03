//
//  FlipToRecordModelTests.swift
//  PlayolaRadio
//

import Clocks
import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct FlipToRecordModelTests {
  @Test
  func testExternalMicStartsRecordingWithoutPrompt() async {
    await withMainSerialExecutor {
      let harness = FlipHarness(usesExternalMicrophone: true)

      await harness.model.recordTapped()

      expectNoDifference(harness.events.value, ["start"])
      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.updatesCalls.value, 0)
    }
  }

  @Test
  func testDeniedPermissionHandsOffToThePageStart() async {
    await withMainSerialExecutor {
      let harness = FlipHarness(hasPermission: false)

      await harness.model.recordTapped()

      expectNoDifference(harness.events.value, ["start"])
      expectNoDifference(harness.model.phase, .idle)
    }
  }

  @Test
  func testPromptTitleExplainsHowToStartAndStop() {
    let harness = FlipHarness()

    expectNoDifference(
      harness.model.promptTitle, "Flip your phone to start.\nFlip it back to stop.")
  }

  @Test
  func testHeldUprightShowsPrompt() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()

      await harness.model.recordTapped()
      await harness.send(.upright)

      expectNoDifference(harness.model.phase, .prompting)
      expectNoDifference(harness.events.value, [])
    }
  }

  @Test
  func testPoseStreamEndingBeforeAnySampleRecordsUpright() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()

      await harness.model.recordTapped()
      harness.poseInput.finish()
      await Task.megaYield()

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["start"])
    }
  }

  @Test
  func testPoseStreamEndingWhilePromptingRecordsUpright() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)

      harness.poseInput.finish()
      await Task.megaYield()

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["start"])
    }
  }

  @Test
  func testCancelDuringPermissionNeverShowsPrompt() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let harness = FlipHarness(permissionGate: gate)

      let tap = Task { await harness.model.recordTapped() }
      await Task.megaYield()
      await harness.model.cancelTapped()
      openGate.yield()
      await tap.value

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.updatesCalls.value, 0)
    }
  }

  @Test
  func testSecondRecordTapWhilePromptingIsIgnored() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)

      await harness.model.recordTapped()

      expectNoDifference(harness.model.phase, .prompting)
      expectNoDifference(harness.updatesCalls.value, 1)
    }
  }

  @Test
  func testAlreadyUpsideDownSkipsPromptAndCountsDown() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()

      await harness.model.recordTapped()
      await harness.send(.upsideDown)
      await harness.clock.advance(by: .milliseconds(250))

      expectNoDifference(harness.model.phase, .countdown(3))
      expectNoDifference(harness.events.value, ["rotate true"])
    }
  }

  @Test
  func testBriefFlipDoesNotStartCountdown() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)

      await harness.send(.upsideDown)
      await harness.clock.advance(by: .milliseconds(200))
      await harness.send(.indeterminate)
      await harness.clock.advance(by: .milliseconds(100))

      expectNoDifference(harness.model.phase, .prompting)
      expectNoDifference(harness.events.value, [])
    }
  }

  @Test
  func testCancelledFlipHoldDoesNotStartCountdown() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upsideDown)

      await harness.model.recordingStopped()
      await harness.clock.advance(by: .milliseconds(250))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, [])
    }
  }

  @Test
  func testFlipFromPromptCountsDownThenStartsRecording() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)
      await harness.send(.upsideDown)
      await harness.clock.advance(by: .milliseconds(250))

      expectNoDifference(harness.model.phase, .countdown(3))
      await harness.clock.advance(by: .seconds(1))
      expectNoDifference(harness.model.phase, .countdown(2))
      await harness.clock.advance(by: .seconds(1))
      expectNoDifference(harness.model.phase, .countdown(1))
      await harness.clock.advance(by: .seconds(1))

      expectNoDifference(harness.model.phase, .recordingFlipped)
      expectNoDifference(harness.events.value, ["rotate true", "start"])
    }
  }

  @Test
  func testUprightDuringCountdownRotatesBackToPrompt() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startCountdown()

      await harness.send(.upright)
      await harness.clock.advance(by: .seconds(3))

      expectNoDifference(harness.model.phase, .prompting)
      expectNoDifference(harness.events.value, ["rotate true", "rotate false"])
    }
  }

  @Test
  func testIndeterminateDuringCountdownKeepsCounting() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startCountdown()

      await harness.send(.indeterminate)
      await harness.clock.advance(by: .seconds(1))

      expectNoDifference(harness.model.phase, .countdown(2))
    }
  }

  @Test
  func testCancelDuringCountdownNeverStartsAndRotatesBack() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startCountdown()

      await harness.model.cancelTapped()
      await harness.clock.advance(by: .seconds(3))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "rotate false"])
    }
  }

  @Test
  func testCancelledCountdownAfterATickDoesNotContinue() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startCountdown()

      await harness.model.cancelTapped()
      await harness.clock.advance(by: .seconds(3))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "rotate false"])
    }
  }

  @Test
  func testCancelAfterRotationFinishesLateReleasesIt() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let owner = LockIsolated<UUID?>(nil)
      let orientation = RecordingOrientationClient(
        acquire: { id in
          for await _ in gate { break }
          owner.setValue(id)
          return true
        },
        release: { id in
          guard owner.value == id else { return }
          owner.setValue(nil)
        },
        isOwner: { owner.value == $0 },
        forceReset: { owner.setValue(nil) }
      )
      let harness = FlipHarness(orientation: orientation)
      await harness.startCountdown()

      await harness.model.cancelTapped()
      openGate.yield()
      await Task.megaYield()

      expectNoDifference(owner.value, nil)
    }
  }

  @Test
  func testCancelWhileRotatingNeverStarts() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let harness = FlipHarness(rotationGate: gate)
      await harness.model.recordTapped()
      await harness.send(.upsideDown)
      await harness.clock.advance(by: .milliseconds(250))

      await harness.model.cancelTapped()
      openGate.yield()
      await Task.megaYield()
      await harness.clock.advance(by: .seconds(3))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "rotate false"])
    }
  }

  @Test
  func testOrientationResetDuringCountdownGoesIdle() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startCountdown()

      await harness.controller.forceReset()
      await harness.clock.advance(by: .seconds(1))
      await harness.send(.upsideDown)
      await harness.clock.advance(by: .seconds(5))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "rotate false"])
    }
  }

  @Test
  func testBackgroundingWhileWaitingForFlipGoesIdle() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upsideDown)

      await harness.model.scenePhaseChanged(newPhase: .background)
      await harness.clock.advance(by: .seconds(5))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, [])
    }
  }

  @Test
  func testBackgroundingWhileRecordingFlippedKeepsRecording() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startRecording()

      await harness.model.scenePhaseChanged(newPhase: .background)

      expectNoDifference(harness.model.phase, .recordingFlipped)
      expectNoDifference(harness.events.value, ["rotate true", "start"])
    }
  }

  @Test
  func testRecordTapWhileStartingWithoutMotionIsIgnored() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let harness = FlipHarness(startGate: gate)
      await harness.model.recordTapped()
      harness.poseInput.finish()
      await Task.megaYield()

      await harness.model.recordTapped()
      openGate.yield()
      await Task.megaYield()

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.updatesCalls.value, 1)
    }
  }

  @Test
  func testCancelFromPromptReturnsToIdle() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)

      await harness.model.cancelTapped()

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, [])
    }
  }

  @Test
  func testHoldingUprightForASecondStopsAndRotatesBack() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startRecording()

      await harness.send(.upright)
      await harness.clock.advance(by: .seconds(1))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "start", "stop", "rotate false"])
    }
  }

  @Test
  func testTurningBackOverBeforeASecondKeepsRecording() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startRecording()

      await harness.send(.upright)
      await harness.clock.advance(by: .milliseconds(600))
      await harness.send(.upsideDown)
      await harness.clock.advance(by: .seconds(2))

      expectNoDifference(harness.model.phase, .recordingFlipped)
      expectNoDifference(harness.events.value, ["rotate true", "start"])
    }
  }

  @Test
  func testIndeterminateDoesNotResetTheUprightTimer() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startRecording()

      await harness.send(.upright)
      await harness.clock.advance(by: .milliseconds(600))
      await harness.send(.indeterminate)
      await harness.clock.advance(by: .milliseconds(400))

      expectNoDifference(harness.events.value, ["rotate true", "start", "stop", "rotate false"])
    }
  }

  @Test
  func testStartFailureRotatesBack() async {
    await withMainSerialExecutor {
      let harness = FlipHarness(startSucceeds: false)
      await harness.startCountdown()

      await harness.clock.advance(by: .seconds(3))

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "start", "rotate false"])
    }
  }

  @Test
  func testUprightWhileStartIsPendingStopsTheRecordingOnceItBegins() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let harness = FlipHarness(startGate: gate)
      await harness.startRecording()

      await harness.send(.upright)
      await harness.clock.advance(by: .seconds(1))
      openGate.yield()
      await Task.megaYield()

      expectNoDifference(
        harness.events.value, ["rotate true", "start", "stop", "rotate false", "stop"])
    }
  }

  @Test
  func testLeavingWhileStartIsPendingDoesNotStopTheRecording() async {
    await withMainSerialExecutor {
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let harness = FlipHarness(startGate: gate)
      await harness.startRecording()

      await harness.model.recordingStopped()
      openGate.yield()
      await Task.megaYield()

      expectNoDifference(harness.events.value, ["rotate true", "start", "rotate false"])
    }
  }

  @Test
  func testPageStopWhileFlippedRotatesBack() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.startRecording()

      await harness.model.recordingStopped()
      await Task.megaYield()

      expectNoDifference(harness.model.phase, .idle)
      expectNoDifference(harness.events.value, ["rotate true", "start", "rotate false"])
    }
  }

  @Test
  func testRecordingStoppedDoesNotWaitForRotationToFinish() async {
    await withMainSerialExecutor {
      let (releaseGate, openReleaseGate) = AsyncStream<Void>.makeStream()
      let owner = LockIsolated<UUID?>(nil)
      let orientation = RecordingOrientationClient(
        acquire: {
          owner.setValue($0)
          return true
        },
        release: { id in
          guard owner.value == id else { return }
          for await _ in releaseGate { break }
          owner.setValue(nil)
        },
        isOwner: { owner.value == $0 },
        forceReset: { owner.setValue(nil) }
      )
      let harness = FlipHarness(orientation: orientation)
      await harness.startRecording()
      let cleanupFinished = LockIsolated(false)
      let cleanup = Task {
        await harness.model.recordingStopped()
        cleanupFinished.setValue(true)
      }
      defer { openReleaseGate.yield() }

      await Task.megaYield()

      expectNoDifference(cleanupFinished.value, true)
      await cleanup.value
    }
  }

  @Test
  func testPromptAndCountdownBlockUnderlyingAccessibilityElements() async {
    await withMainSerialExecutor {
      let harness = FlipHarness()
      await harness.model.recordTapped()
      await harness.send(.upright)

      expectNoDifference(harness.model.blocksUnderlyingAccessibility, true)

      await harness.send(.upsideDown)
      await harness.clock.advance(by: .milliseconds(250))

      expectNoDifference(harness.model.blocksUnderlyingAccessibility, true)
    }
  }
}

@MainActor
private final class FlipHarness {
  let clock = TestClock()
  let events = LockIsolated<[String]>([])
  let updatesCalls = LockIsolated(0)
  let poseInput: AsyncStream<DevicePose>.Continuation
  let controller: RecordingOrientationController
  let model: FlipToRecordModel

  init(
    usesExternalMicrophone: Bool = false,
    hasPermission: Bool = true,
    startSucceeds: Bool = true,
    permissionGate: AsyncStream<Void>? = nil,
    rotationGate: AsyncStream<Void>? = nil,
    startGate: AsyncStream<Void>? = nil,
    orientation: RecordingOrientationClient? = nil
  ) {
    let (poses, poseInput) = AsyncStream<DevicePose>.makeStream()
    self.poseInput = poseInput
    let clock = clock
    let events = events
    let updatesCalls = updatesCalls
    controller = withDependencies {
      $0.windowOrientation.setUpsideDown = { isUpsideDown in
        events.withValue { $0.append("rotate \(isUpsideDown)") }
        guard isUpsideDown, let rotationGate else { return true }
        for await _ in rotationGate { break }
        return true
      }
      $0.upsideDownKeyboard.setUpsideDownModeEnabled = { _ in }
      $0.upsideDownNotificationBanner.setUpsideDownModeEnabled = { _ in }
    } operation: {
      RecordingOrientationController()
    }
    let controller = controller
    model = withDependencies {
      $0.continuousClock = clock
      $0.uuid = .incrementing
      $0.audioRecorder.requestPermission = {
        if let permissionGate {
          for await _ in permissionGate { break }
        }
        return hasPermission
      }
      $0.audioRecorder.usesExternalMicrophone = { usesExternalMicrophone }
      $0.devicePose.updates = {
        updatesCalls.withValue { $0 += 1 }
        return poses
      }
      $0.recordingOrientation = orientation ?? Self.orientation(controlledBy: controller)
    } operation: {
      FlipToRecordModel()
    }
    model.start = {
      events.withValue { $0.append("start") }
      if let startGate {
        for await _ in startGate { break }
      }
      return startSucceeds
    }
    model.stop = { [weak model] in
      events.withValue { $0.append("stop") }
      await model?.recordingStopped()
    }
  }

  private static func orientation(
    controlledBy controller: RecordingOrientationController
  ) -> RecordingOrientationClient {
    RecordingOrientationClient(
      acquire: { await controller.acquire($0) },
      release: { await controller.release($0) },
      isOwner: { controller.isOwner($0) },
      forceReset: { await controller.forceReset() }
    )
  }

  func send(_ pose: DevicePose) async {
    poseInput.yield(pose)
    await Task.megaYield()
  }

  func startCountdown() async {
    await model.recordTapped()
    await send(.upsideDown)
    await clock.advance(by: .milliseconds(250))
  }

  func startRecording() async {
    await startCountdown()
    await clock.advance(by: .seconds(3))
  }
}
