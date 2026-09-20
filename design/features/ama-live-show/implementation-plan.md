# Ask Me Anything live page implementation plan

Consumer: `superpowers:executing-plans`, in this workspace.

Goal: implement the owner's `AMA_IOS_PROMPT.md` handoff as one small iOS change.
Base: `dd93bef9` (includes the completed API layer and PlayolaPlayer 0.21.1).
Server contract inspected: `/Users/brian/playola/playola`, `origin/develop` at `d9a05774`.

Scope: reuse the opener builder while inactive and the existing Broadcast model/view while active. Keep the API layer intact. No new scheduler, poller, phase enum, persistence, environment gates, or canvas redesign. The owner's explicit implementation handoff supersedes the usual separate design PR. Keep the current branch as instructed by the workspace.

Product choices: the owner explicitly chose to HIDE filler songs and record an outro. Filler still counts for active-show detection, matching the server. A terminal drop target places new content before the removable filler tail using the existing insert endpoint.

## 1. Reuse Broadcast with a show filter

- [x] Add a failing queue-filter regression test alongside the full existing `BroadcastPageTests` suite.
- [x] Add `liveShowId: String? = nil` to `BroadcastPageModel.init` and filter `upcomingSpins` before its optimistic ordering. Leave now-playing, insert, delete, move, tick, and schedule notifications on their existing paths.
- [x] Verify the default nil filter retains normal Broadcast behavior; verify filler hiding, other-show exclusion, and now-playing.

## 2. Turn setup into the live page

- [x] Rename `AskMeAnythingSetupPage` model/view/tests and folder to `AskMeAnythingLivePage`, updating explicit Xcode registrations and route references.
- [x] On initial appearance, fetch the extended schedule and detect the current or nearest future live-show spin (including filler, which the server treats as active). Use one composed `BroadcastPageModel` to load and observe the schedule, then render the extracted `BroadcastContentView`.
- [x] Start with the ready opener's audio IDs in order; preserve state on request failure and show an understandable unavailable/delay message. Prevent concurrent start requests and incomplete uploads from being submitted.
- [x] End through a recorded outro and the existing end endpoint. Preserve the uploaded outro on API failure for retry; keep the live editor visible through the scheduled ending. Do not treat all HTTP 400 responses as successful completion: the server also uses them for unsafe scheduling positions.
- [x] Keep content and active/setup/loading rendering decisions in the model. Use the existing Broadcast updates and clock for expiration, without adding a poller.
- [x] Add tests for detection (including a future opener and including filler-only and excluding expired schedules), ordered start, unavailable/failure states, end success/failure, and duplicate submissions.

## 3. Verify integration

- [x] Preserve abandoned-setup upload cancellation under the renamed navigation route.
- [x] Run all touched suites: AMA, Broadcast, Shows, navigation coordinator, and recorder if changed.
- [x] Run Swift formatting and strict lint; inspect the final diff.
- [x] Run one Claude adversarial review, following the handoff's light-review instruction and the global provider swap.

Test command (fresh DerivedData resolves the pinned SDK):

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer xcodebuild test \
  -project PlayolaRadio.xcodeproj -scheme PlayolaRadio -skipPackagePluginValidation \
  -derivedDataPath /tmp/ama-live-tacoma-dd \
  -destination 'platform=iOS Simulator,id=997DAE14-2CBC-4944-ABB0-E86073E1668C' \
  -only-testing:PlayolaRadioTests/AskMeAnythingLivePageTests \
  -only-testing:PlayolaRadioTests/BroadcastPageTests \
  -only-testing:PlayolaRadioTests/ShowsPageTests \
  -only-testing:PlayolaRadioTests/MainContainerNavigationCoordinatorTests \
  -only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests
```

Server dependency: the inspected server `origin/develop` does not yet auto-tag ordinary inserted/moved spins with the active show ID. The companion server change must land for newly placed content to appear in this filtered queue. No server code is changed here.

Architecture review: Claude recommended one composed Broadcast model and extracting its content view to avoid duplicate loading, misleading screen analytics, and competing navigation titles. Adopted. Detection includes filler because the server keeps that show active; this corrects the handoff’s non-filler assumption. Initial red tests exposed the stubbed start and missing queue filter; a test date-provider scope was corrected before evaluating the filter failure.

Owner steering: hide filler songs; record an outro. Queue-end placement uses the full schedule to resolve its insertion anchor, preserving the hidden filler boundary.

Verification: 171 tests passed across the five touched suites; strict SwiftLint passed with zero violations. Claude review completed; dispositions below.

## Final review dispositions

- Rejected expired-spin lockout finding: pinned SDK `Schedule.current()` explicitly filters `endtime > dateProvider.now()`, and both SDK source and the expiration regression test verify it. Adding the same predicate would duplicate the existing scheduler.
- Added schedule-change detection alongside playback-change detection so remote edits are recognized even when now-playing remains unchanged. No additional timer or poller.
- Deferred the end request until the AMA page reappears after outro recording. Errors and progress now belong to the visible page, while failed submissions retain the uploaded outro for an explicit retry.
- Anchored moves to the front of the filtered queue after the actual predecessor of the show's first visible spin, preserving rotation before a scheduled show. Default Broadcast behavior is unchanged.
- Kept the actual predecessor for terminal inserts: the required behavior is to insert immediately before the removable filler boundary using the existing scheduler, which requires the predecessor in the full schedule.
- Kept existing insertion-error copy for default Broadcast; changing it is outside this feature and the no-anchor condition is handled by the same scheduler guard.

The two concrete behavior corrections were reproduced with failing tests before implementation. The owner's light-review instruction is honored with one external code-review pass; final regression checks cover the corrections.

## Dedicated AMA design follow-up (2026-09-19)

Owner approved the four supplied exports and showing promoted filler while keeping reserve filler hidden. This supersedes the embedded Broadcast view and unconditional filler hiding above. Keep BroadcastPageModel for schedule mutations only.

1. Model and regression tests: derive waiting/countdown, visible queue, 10-minute buffer, and three-minute filler reveal from the real schedule. Retain revealed IDs for this page lifetime; intersect against each refreshed schedule. No scheduler, phase enum, persistence, or network poller. Read listener count and Q/A metadata from existing endpoints on appearance. Preserve recorded-outro ending.
2. Dedicated AMA rendering: match exported header, now-playing strip, grouped Q/A rows, action card, and pinned footer. Reuse existing insertion/move/delete operations. Automatically append successful songs/voicetracks before reserve filler; provide retry for failed adds. Preserve the approved native three-tab shell. Waiting footer uses truthful “Show starts automatically”; notification delivery has no client confirmation.
3. Verify: focused regressions, full touched suites, four simulator-rendered states, formatting/lint, one light Claude review.

Architecture consultation: keep shared insertion anchor resolution. Reject showing all filler because it contradicts the owner's explicit selection. Three-minute promotion is presentation of audio already on the server schedule, not a new insertion request. Use the exact existing amber/green tokens. Validate List rendering with UIKit, not ImageRenderer. Pinned SDK source is present in /tmp/ama-live-tacoma-dd. Server auto-tagging landed on origin/develop at 53d7b6a3, superseding the earlier dependency warning.

Follow-up contract trace: the current server's classifier accepts inserts before its first removable filler. A visually revealed song remains removable until two minutes before airtime; new host audio replaces that fallback rather than being inserted outside the show. The insertion boundary therefore intentionally includes visible-but-removable filler. Q/A deletion uses the existing single-spin endpoint in reverse order (answer then question), stopping on failure; moves retain server-side grouping. Icons are the exact SVG vectors extracted from the supplied HTML exports.

Follow-up verification: 180 tests passed across AMA presentation, AMA live page, Broadcast, Shows, navigation coordinator, and recorder suites. Strict SwiftLint: zero violations. Full swift-format check passed. All four content states were rendered in the iOS Simulator at the exported 393-point width and visually compared; the temporary rendering harness was removed. Artifacts remain in the workspace's ignored .context/ama-visual-validation directory. The checked-in tests cover countdown boundaries, filler reveal/confirmation expiry, normal buffer, grouped Q/A move/delete, hidden insertion boundary, retry, live voicetrack upload/append, and actual listener-count query parameters.

Follow-up review dispositions (one light Claude pass):
- Rejected the alleged nil-group data-loss path: the existing predicate includes `spin.spinGroupId != nil`, so a nil group makes the entire conjunction false. Added a passing regression proving an ungrouped question stays separate and deleting it preserves the unrelated song.
- Rejected duplicate insertion/orphan claims: the MainActor guard and setting `isAddingToShow` have no intervening suspension; the reviewer also recognized this. The single retry action intentionally drains every queued item, so later items are not orphaned. This serves the automatic-append/retry requirement without parallel insertion calls.
- Fixed failed-add copy to say audio is ready for retry rather than suggesting it was added. The existing failure/retry test now asserts the copy.
- Removed the empty footer message's spacing and let visible message text use its intrinsic height, aligning End Show with the exported normal/low/confirmation positions. Re-rendered all four states in the simulator.

Final verification after review: 181 regression tests pass across all six touched suites; zero strict lint violations and a clean full format check. No temporary rendering code remains in the test target. No API/server changes were needed.
