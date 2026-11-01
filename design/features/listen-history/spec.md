# Song listening history — design

## Scope

Let a signed-in listener open Listening History from the compact entry on Your Library, see the songs the server says they heard, including the Playola station and spin airtime, and add or remove each song from the existing Liked Songs collection. The detail page is newest first, grouped by the phone's local date, and paginated 20 spins at a time.

**Source of truth:** the existing `GET /v1/users/me/play-history?type=song&limit=20&offset=…` response. The server already maintains and refreshes this history from listening sessions and scheduled spins. The iOS app displays that result; it does not infer, record, merge, or correct plays itself. History can be incomplete or imprecise because the server's source is best effort. The row time is the spin's scheduled airtime, not the exact instant the user began listening.

**Refresh:** entering the Your Library root from another tab fetches page one from the server. When Listening History is already open on the Library navigation stack, returning to that tab keeps the loaded pages and scroll position; pull-to-refresh remains available in the detail. The result is held in memory for Listening History. Opening the detail reuses an in-flight request or a successful result from the last 60 seconds; an older result starts a new page-one request so a listener who stayed on Library can see a recently heard song. Returning from the detail page, or tapping the already-selected Library tab, does not trigger another fetch. Opening the detail ensures page one is loaded for the current account if tab entry did not start it, including after sign-in while Library remained selected. A saved Library prefetch failure is retried once when detail opens. Pull-to-refresh on the detail also starts again at page one.

Target surface: iOS. This design session changes no application or backend code.

## Decisions and approvals

- **Compact Your Library entry:** Pen frame `VnLyt`, the original A direction, visually locked by the user on 2026-09-23. It sits between Presets and Liked Songs.
- **Populated Listening History detail:** Pen frame `DageM`, visually locked on 2026-09-23. Each row shows song, artist, channel and local time, with a heart action.
- **Supporting detail states:** `GNMt9` loading, `Nnpzb` empty, `W16HKe` initial error, `kyCIW` signed out, `d8xmZF` loading more, and `m5BmO` later-page error. The user approved all six on 2026-11-01.
- **Pagination:** the user requested a bounded number of items at a time. The design uses 20 per request and loads later pages on demand.
- **Server-only history:** on 2026-11-01 the user superseded the earlier hybrid recording proposal: “All of this is stored on the server… Let's just display what the server shows.” The previously approved `songPlays` model, report endpoint, backend session changes, and two-implementation-PR graph are withdrawn from this feature. The user then confirmed that a complex recording path makes no sense for this screen.
- **Library refresh:** the user added, “We can reload when they go to the library page.” The page-one request runs on Library tab selection and is reused by the detail page.

## Acceptance criteria

- Your Library shows the approved compact entry. Tapping it pushes Listening History on the Library navigation stack; Back returns to Your Library.
- Entering the Your Library root from another tab requests `GET /v1/users/me/play-history` with `type=song`, `limit=20`, and `offset=0`. Returning to that root refetches page one; returning while the history detail is open keeps its loaded pages. The detail reuses an in-flight or at-most-60-second-old successful result, and otherwise refreshes it. A failed Library prefetch retries automatically on detail open. Popping back from detail does not refetch.
- The detail shows only rows returned by the server, newest first, with the song, artist, `station.name`, and local time derived from `spin.airtime`. The same spin ID appears once if offset pages shift while browsing.
- A row's heart uses the existing LikesManager and Liked Songs API, passing the spin ID as context. Every appearance of the same `audioBlockId` reflects the same like state. Row body taps have no separate action in v1. The existing like toast's “View all” action navigates to Liked Songs and can close History.
- As the fifth-from-last loaded row appears, the detail requests one later page at a time. The next offset equals the previous offset plus the number of spins in the server response, even if duplicate or unusable rows are dropped locally. `pagination.hasMore` determines whether another page exists. If a fetched page yields no display rows and `hasMore` is true, the detail immediately requests the next 20-item page, repeating until a page yields rows or `hasMore` is false; a response with no spins ends paging.
- Later-page failure preserves loaded rows and shows Retry. Pull-to-refresh cancels or invalidates an older page request and starts at offset zero. Any page-one refresh keeps loaded rows until it succeeds; if it fails, the loaded rows remain with a transient error message, or the initial error state appears if there are no rows. Initial loading, empty, initial error, signed-out, loading-more, and later-page-error states match the approved frames.
- On account change or sign-out, no cached row from the prior user is displayed, and responses started for the prior user are ignored. A 401 on a pushed detail page shows the approved sign-in state; its Sign In action signs out through the existing flow so the app root presents Sign In. 403, 503, and other load errors use the error state.

## Non-goals

- New server endpoints, tables, migrations, listening-session behavior, or playback event reporting.
- Improving, backfilling, or labeling the server's inference accuracy in this feature.
- A separate Favorites collection, search, filters, export, play counts, history deletion, or song-row playback.
- Song history for URL streams without Playola scheduled spins, or listening before the server's 2026-01-01 history floor.

## Existing contracts inspected

| Existing piece | Relevant behavior |
| --- | --- |
| `GET /v1/users/:userId/play-history` | Self or admin; `me` alias; `type=song`; `limit` defaults to 50 and caps at 100; `offset` defaults to zero. Returns `{spins: [populated Spin], pagination: {limit, offset, total, hasMore}}`, newest first. It refreshes stored history on read and includes recent live sessions. Backend `origin/develop` inspected at `77513f9569d25a5835a66a0f3ca7f138989b2546`. |
| `Spin` / `AudioBlock` / `Station` | A spin supplies ID and airtime; its populated audio block supplies song title, artist, artwork, and ID; its populated station supplies the channel name. A deleted related record may remove a row or leave an optional association. |
| `LikesManager` | Existing optimistic like/unlike action accepts an `AudioBlock` and optional spin ID. Likes are shared by audio-block ID across repeated airings. |
| Your Library | `YourLibraryPageModel` and `YourLibraryPageView` currently show Presets and Liked Songs. `MainContainer` owns the Library tab and its navigation stack. |

The current Your Library screenshot is in `exports/existing/your-library--current.png`. The selected mockups and all approved states are in [screens.md](./screens.md).

## iOS loading and presentation rules

- The Library entry remains compact and has no song preview. The page-one fetch occurs for freshness, while the detail owns the visible loading and error presentation.
- Use a history-specific response type for the page. Decode only the top-level spin fields needed for history plus its populated song and station. Keep the full existing `AudioBlock` for the LikesManager action. Skip a row with a missing association. An unexpected malformed response shows the appropriate load error.
- Group combined pages by local calendar day. Headings are “Today”, “Yesterday”, or a local calendar date for older days; row time uses `h:mm a` in the phone's timezone. A date group may continue across page boundaries.
- The endpoint uses offset pagination, so new or removed spins can shift later pages. De-duplicate by spin ID in memory, keep the server's offset arithmetic, and refresh from page one when the listener returns to Your Library or pulls to refresh.
- The app currently replaces all tabs with Sign In when signed out. The approved signed-out detail frame is used if a pushed page receives 401 while auth still appears present; its button calls the existing sign-out flow. If auth has already cleared, the app root presents Sign In directly.

## Design review disposition

Earlier Claude architecture and adversarial reviews examined a larger hybrid recording proposal. The user's later server-only direction supersedes that proposal and its related findings. A fresh architecture review of the server-only revision found that Library root `.task` can restart on Back and cancel an in-flight fetch. Resolved: refresh on tab transition, hold the page request in the Library-owned history model, and let detail ensure it is loaded. It also found stale-account exposure; resolved by checking account identity before displaying or applying any response. The approved signed-out frame remains reachable on 401 and its button uses existing sign-out. No backend fix is a dependency of displaying the existing server response.

The server-only adversarial review found that History could reuse a Library result long after a song played. **Resolved:** detail refreshes a success older than 60 seconds. It found that a transient Library prefetch failure could linger until manual Retry. **Resolved:** detail retries that failure once on open. It noted server cost on every tab entry. **Accepted:** the user explicitly requested Library-entry refresh; calls still coalesce while page one is in flight. It noted the existing like toast can navigate away, missing spin context, 401/503 classification, and refresh-failure presentation. **Resolved:** acceptance criteria above state those behaviors.

The simplicity audit proposed loading only when detail opens. **Rejected:** that would reverse the user's Library-entry refresh decision and lose the already approved preloaded detail behavior. It proposed dropping a transport-level API request test, because the existing fixed `apiSession` has no test seam. **Adopted:** test response decoding and trace the one-line live request against the server route in final review. It proposed treating 403 like other non-401 errors. **Adopted:** one non-401 error branch. It proposed paging at the last row. **Rejected:** keep the fifth-from-last trigger so the approved loading-more state appears before the listener reaches the end; this needs only a row-index check.

## Design deliverables

- Screens: [screens.md](./screens.md)
- Endpoints: none — the feature reads existing `GET /v1/users/me/play-history` and uses existing like/unlike endpoints unchanged.
- Models: none — the feature reads existing server `Spin`, `AudioBlock`, and `Station` data without changing their schemas.

## Base commits

- iOS repository: `cf80be545c0a8e02243c148b88c755b236bec8d4` (`origin/develop` when design began).
- Latest iOS `origin/develop` inspected: `b6e91e804dde788bc1a5af70e7e448871cd5da63` on 2026-11-01.
- Backend `origin/develop` inspected: `77513f9569d25a5835a66a0f3ca7f138989b2546` on 2026-11-01. Its local checkout was behind, so the existing endpoint was inspected through the fetched ref without changing that checkout.
