# Listening History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking. This is one iOS implementation PR after the design PR merges; use a fresh workspace/session. Do not implement in this design session.

**Goal:** Show the server's song play history and its station in Your Library, with 20-row paging and a Liked Songs heart action.

**Architecture:** Add one `ListeningHistoryPageModel` owned by `YourLibraryPageModel`. Entering the Library tab starts its first request; pushing the detail passes the same model, so it uses a recent result or ongoing request. The model refreshes a result older than 60 seconds on detail open, owns only temporary page state, and checks account identity before exposing or applying rows. No recorder, server change, new persistent/shared cache, or history write is involved.

**Tech Stack:** SwiftUI, Observation, Point-Free Dependencies and Sharing, existing APIClient and LikesManager, Swift Testing.

---

## Contracts and scope

- Product intent and acceptance: [spec.md](./spec.md).
- Approved screens and state PNGs: [screens.md](./screens.md), with measurements in `exports/*.json` and tokens in `exports/design-tokens.json`.
- Endpoint changes: none — use existing `GET /v1/users/me/play-history` and existing like/unlike calls unchanged.
- Server model changes: none — read populated spins, songs, and stations as served.
- iOS base inspected: `b6e91e804dde788bc1a5af70e7e448871cd5da63` (`origin/develop` on 2026-11-01); backend contract inspected at `77513f9569d25a5835a66a0f3ca7f138989b2546`. Recheck the implementation branch's current `develop` before coding.
- Target: `playola-radio-ios` only. Use `.claude/PAGE_CREATION.md`, `VIEWS.md`, `API_CLIENT.md`, `NAVIGATION.md`, and `TESTING.md` plus relevant `pfw-*` skills. The history model owns display text and state; views own layout and styling.
- One product PR targets `develop`. No migration, deployment order, feature gate, or backend PR.

## File map

| File | Responsibility |
| --- | --- |
| `PlayolaRadio/Core/API/ListeningHistoryResponse.swift` (new) | Decode the existing history page and populated spin fields used by the screen. |
| `PlayolaRadio/Core/API/APIClient.swift`, `APIClient+Live.swift` (modify) | One typed GET method with `type=song`, `limit=20`, and offset. |
| `PlayolaRadio/Views/Pages/ListeningHistoryPage/ListeningHistoryPageModel.swift` (new) | Temporary rows, paging, account isolation, date groups, state text, like actions. |
| `PlayolaRadio/Views/Pages/ListeningHistoryPage/ListeningHistoryPageView.swift` (new) | The seven approved detail states: populated plus six supporting states. |
| `PlayolaRadio/Views/Pages/ListeningHistoryPage/ListeningHistoryPageTests.swift` (new) | Decode/paging/account/state behavior, including a suspended request stub. |
| `PlayolaRadio/Views/Pages/YourLibraryPage/YourLibraryPageModel.swift`, `YourLibraryPageView.swift`, `YourLibraryPageTests.swift` (modify) | Own the page model and render the compact entry. |
| `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift`, `MainContainerModel.swift`, `MainContainerTests.swift` (modify) | Trigger refresh on Library tab entry; keep existing rating prompt; cover initial Library selection. |
| `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift`, `MainContainerNavigationCoordinatorTests.swift` (modify) | Push the shared detail model and pop on Back. |
| `PlayolaRadio/Core/API/APIClientTests.swift` (modify) | Decode a representative server response and nullable associations. |

## Task 1: Confirm the live contract and add the read method

- [ ] Check the current backend `origin/develop` play-history controller/library output and one real or fixture response. Record the exact JSON shape for `spin.id`, `spin.airtime`, populated `audioBlock`, populated `station`, and `pagination`. Verify the existing `AudioBlock` decoder accepts the populated body used by this endpoint. If it does not, use a thin history song type for display and adapt the Like action through the smallest existing supported `AudioBlock` construction path; do not invent a new likes endpoint.
- [ ] Add a decoding test with a representative response and missing `audioBlock`/`station` rows. A missing related record should skip only that row; malformed pagination should fail the page. Also assert the server's returned spin count is retained separately from usable display rows for offset advancement. Run the focused test and see it fail before implementation.
- [ ] Add `ListeningHistoryResponse` and `APIClient.getListeningHistory(_ jwtToken: String, _ offset: Int)` with a live call to `authenticatedGet(path: "/v1/users/me/play-history", token: jwtToken, queryParams: ["type": "song", "limit": "20", "offset": String(offset)])`. Treat `pagination.hasMore` as authoritative. Decode the representative fixture in `APIClientTests` with `JSONDecoderWithIsoFull`, the same decoder used by the live helper. Run the API tests. Verify path, params, and auth by tracing the live call against the current server route in Task 4; the fixed API session has no test transport seam.
- [ ] Commit this independently testable API change after checks pass.

## Task 2: Load, refresh, and page in one Library-owned model

- [ ] Create `ListeningHistoryPageModel` with private raw rows, owner user ID, request generation, page-one task, last successful page-one time, current offset, `hasMore`, and a small load state. Public display rows must return empty when `auth.currentUser?.id` differs from the owner. Observe the existing `@Shared(.auth)` publisher to invalidate rows when the user ID changes; ignore JWT rotation for the same user. Do not use `@Shared` storage for history. Initialize the model once in `YourLibraryPageModel` and pass that same instance when navigating.
- [ ] Test these transitions first with `@Suite(.freshSharedState)`: `refresh()` requests offset 0; opening detail while it is in flight calls `ensureLoaded()` without making a second request (hold the stub with a continuation, never `Task.sleep`); a successful prefetch under 60 seconds old is reused; one older than 60 seconds refetches; a failed Library prefetch retries once on detail open; `loadMore()` requests only one page at a time; offset advances by the server-returned count; duplicate spin IDs are displayed once; later-page failure keeps prior rows; Retry repeats the failed offset; pull-to-refresh invalidates an older page response. Inject the clock through `@Dependency(\.date.now)` for age tests. Run the focused tests to red, then implement and run to green.
- [ ] A successful page-one refresh replaces rows and resets pagination. A failed refresh keeps previously loaded rows; use the existing toast dependency for detail-initiated refresh failures, and show initial error and Retry if there are no rows. Let the refresh call specify whether its failure should show a toast: Library prefetch is silent, detail open and pull-to-refresh can show it. Add tests for both cases.
- [ ] Test sign-out and account switch: display rows disappear as soon as the owner differs; a late prior-user response cannot repopulate them; `ensureLoaded()` starts a request for the new user even if Library remains selected. Capture user ID and a request generation at start, validate both before every state write. Token refresh for the same user must not clear rows. Run model tests.
- [ ] Test 401 separately from a representative non-401 error using the actual Alamofire status error type returned by `authenticatedGet`; 401 renders the approved signed-out state, whose Sign In action calls the existing `AuthService.shared.signOut()` path; every other failure renders the corresponding error state. If auth has already cleared, the existing `ContentView` sign-in root wins. Avoid adding a new authentication service.
- [ ] Compute Today/Yesterday/older local-date groups and `h:mm a` row labels from the current calendar and date when displayed, so headings do not stay stale across midnight. Expose display-ready strings and row actions from the model. Use `LikesManager.isLiked(audioBlock.id)` and `toggleLike(audioBlock, spinId: spin.id)` so repeated spins share the same liked state. Run model and LikesManager tests for touched shared behavior, then commit.

## Task 3: Render the approved screens and wire navigation

- [ ] Build the compact Library entry from frame `VnLyt`, between Presets and Liked Songs, with no preview or spinner. Its tap pushes `ListeningHistoryPageModel` through a new `MainContainerNavigationCoordinator.Path` case. Add coordinator and Library model tests for the exact route and same model identity.
- [ ] Add a Library-tab transition action to `MainContainerModel`, called from the existing `.onChange(of: model.activeTab)` in `MainContainer` when the new value is `.yourLibrary`. Keep the rating-prompt action. Trigger once on initial appearance if Library is already selected; skip duplicate refresh while page one is in flight. Root `YourLibraryPageView.task` continues loading presets only, so Back from detail does not reset history. Add model tests for tab switch, initial selection, and no refresh on Back.
- [ ] Render `DageM`, `GNMt9`, `Nnpzb`, `W16HKe`, `kyCIW`, `d8xmZF`, and `m5BmO` from the exported JSON/PNGs. Detail `onAppear` calls `ensureLoaded()`; `.refreshable` awaits the page-one request; the fifth-from-last visible row calls `loadMore()`. Empty Explore Stations changes to the Radio Stations tab and clears the Library detail path. Back uses normal navigation. Row body has no playback action; heart uses the model's Like action. Keep all text in the model.
- [ ] Verify the seven state transitions in model tests and inspect the view in simulator against the approved PNGs at the target iPhone size. Test a real server response if a safe test account is available; otherwise use the representative backend fixture and state the limit in the PR. Commit after the affected checks pass.

## Task 4: Final verification and handoff

- [ ] Run `make lint` and `make format-check`. Run the full touched-area suites: APIClient, YourLibrary, MainContainer, NavigationCoordinator, LikesManager, and new ListeningHistory tests. On the inspected machine, the command is `xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1'`; substitute an available iPhone simulator only if that device has changed. This also builds the iOS target. Fix failures before committing.
- [ ] Trace the real client/server contract end to end: query names/values, authorization token, response envelope, date decoding, missing association behavior, and 401 error type. Ensure request stubs match the server rather than only each other.
- [ ] Review `git diff origin/develop...` for any recorder, new persistence, backend work, or unrelated changes. Run the repo-required Claude read-only code review, challenge, and excess audit for this product change, apply one combined fix wave, and rerun affected checks. Then commit/push the feature PR to `develop` under the repository's PR workflow.

## Unresolved questions

None. Server history is best effort, and shifted offset pages can miss rows; the agreed UI displays the server's result without correcting it. Reconfirm only if the live endpoint body differs materially from the inspected contract.
