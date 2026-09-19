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
- [ ] Run one Claude adversarial review, following the handoff's light-review instruction and the global provider swap.

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

Verification: 169 tests passed across the five touched suites; strict SwiftLint passed with zero violations. Final review pending.
