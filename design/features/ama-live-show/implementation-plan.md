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

## Immediate opener and scheduling feedback (2026-09-19)

Owner requested reusing Broadcast's processing behavior and showing the known opener immediately after Start succeeds. Broadcast's ScheduleRowView replaces airtime with a gray 0.8-scale spinner driven by spinIdsBeingRescheduled; moves mark all rows and deletes mark the downstream suffix. Insert lacked this state.

Implementation: retain the existing openingItems until the accepted liveShowId appears in the fetched schedule; render them as non-editable presentation rows with independent display IDs, never synthetic server spins. Preserve accepted identity across failed/empty reads and expose the existing retry action on the active card. Initialize the waiting clock at acceptance. AMA uses the existing shared rescheduling IDs (any Q/A member), and insertion marks/clears its affected suffix. Show a small card progress indicator for operations whose affected rows are hidden. Serialize AMA queue edits and disable conflicting actions while processing. Keep the approved layout, no scheduler/poller/persistence/API changes.

Architecture consultation: adopted keeping openingItems rather than a separate provisional-row store, guarding identity detection while awaiting confirmation, and matching Broadcast's spinner styling. The suggested countdown-only alternative would not satisfy the owner's explicit request to populate the list, so provisional display rows remain. Schedule reconciliation uses liveShowId for the whole authoritative batch, not fabricated per-spin IDs.

Verification for immediate opener/feedback: 186 regression tests plus a temporary two-state simulator rendering check passed across the six AMA/Broadcast/Shows/navigation/recorder suites. Tests gate real async boundaries for accepted-but-unconfirmed start, empty/failed refresh and retry, ticking countdown, insert success/failure, move rollback, downstream-only delete progress, and draining an upload completed during an edit. Strict lint and full formatting pass. Temporary rendering code removed; captures are in .context/ama-processing-validation. Background uploads queued during a serialized edit drain through the existing append path after that edit finishes.

## Ordered in-schedule uploads and outro (2026-09-20)

Owner explicitly requested placing live recordings at the playlist bottom immediately, with Broadcast staging visuals followed by Scheduling; songs added afterward preserve their place. Owner extended the same behavior to the recorded outro. This is an approved iteration on the existing design: reuse StagingRowView inside the AMA list, without a separate staging tray. No new canvas direction or API changes.

Plan:
1. Keep openingItems for setup only. Reuse broadcast.stagingItems as the single ordered live pending list; append LocalVoicetrack on acceptance, update it in place through upload, and retain its UUID identity. Songs append synchronously on selection. Preserve existing duplicate-song suppression.
2. Derive AMA scheduling/failure presentation through a StagingItem adapter and reuse Broadcast's row renderer. Pending rows appear after saved rows, before Add. Keep pending rows out of server-spin move/delete indices. Allow discarding unscheduled rows (including failed uploads); scheduling failures have row retry. Upload failures retain an error row with discard/re-record, following existing temporary-file cleanup.
3. Drain only a ready head through existing insertStagingItem. Stop quietly for upload, explicitly for failure. Resume after upload, appearance, edits, or discard. A MainActor synchronous check-and-set serializes drains; the loop rereads the queue after every await. No second pending store, no extra drain-request flag.
4. Outro uses deferred acceptance (clear its blocking-upload callback at the page call site), appends a Show Outro LocalVoicetrack, and closes additions after acceptance. Identify this terminal item by staging ID; when it reaches the ready head, call endLiveShow, never insertSpin. Retain uploaded audio for failed-end retry. On accepted end, retain presentation until endingSpinId is observed; refresh can reconcile without resubmitting end. End stays disabled once accepted.
5. Guard callbacks by show identity and item presence, cancel on abandonment/replacement, and never reappend removed uploads. Decouple add permission from in-flight insertion so later songs can queue. Keep server edits serialized; pending rows cannot be reordered across saved rows.
6. Verify ordered voice/song/outro with suspended async boundaries; reverse upload completion; failed insert/end and discard recovery; accepted-end/failed-refresh; replacement/cancellation; all existing AMA/Broadcast/navigation/recorder suites, format/lint, and simulator render. One light final Claude review per original handoff.

Architecture dispositions: adopted head readiness, failure/discard, stable local identity, separate terminal end operation, identity/cancellation guards, and row-local status. Rejected a second pending list (existing StagingItem supports all required audio; duplicate-song suppression is existing behavior). Rejected alleged MainActor interleaving between a synchronous guard and flag assignment; no await exists there and the loop rereads new entries. No opener-upload migration: Start requires every opener ready and additions stay disabled until its schedule is confirmed. Scheduling remains AMA presentation state rather than a new upload-service enum case. No server or persisted-model changes.

Verification: 190 permanent regression tests plus one temporary two-state simulator rendering test pass across AMA presentation/page, Broadcast, Shows, navigation coordinator, and recorder. Rendered upload percentage, waiting song, outro normalization, and Scheduling using Broadcast's StagingRowView; captures are in .context/ama-ordered-validation. Temporary render code removed. Strict lint (360 source files) and full format check pass. Suspended tests confirm voice → song → outro even when outro upload finishes first, row scheduling state, no duplicate concurrent drain, failed-upload discard, failed-end retry without reupload, accepted-end failed-refresh recovery without resubmission, replacement during upload, and stale insertion response rejection. Existing initial tests reproduced the reversed voice/song order and missing outro deferred acceptance before implementation.

Contract trace: APIClient+Live POST /v1/spins sends audioBlockId/placeAfterSpinId and decodes the returned [Spin]. Server api/spin/spin.controller.ts and lib scheduler resolve that predecessor and return the refreshed playlist. POST /v1/stations/:stationId/liveShow/:liveShowId/end sends audioBlockId; api/liveShow controller and lib/liveShows/liveShows.lib.ts return endingSpinId/effectiveEndsAt, append after retained show members, and return the existing ending id on retry. Client 409/400 mappings and other API error handling are unchanged. Source inspected in /Users/brian/conductor/workspaces/playola/georgetown at 0b43d118. No new concurrency token or API shape. Shared insert now ignores both success/error responses if its captured liveShowId has changed; full Broadcast regression suite passes.
