# Prize Giveaway "coming up" indicator — Design

**Date:** 2026-06-25
**Status:** Approved (pending spec review)
**Branch:** briankeane/curitiba-v2

## Problem

When a Prize Giveaway is about to start, the server sends a push notification. But
when the user opens the app and lands on the station, there is nothing on screen
indicating a giveaway is imminent. The tap button only appears at the moment the
contest opens (`.open`), so the gap between "got the push" and "button reveals"
shows a dead, normal-looking station. We need a visual indicator that a Prize
Giveaway is coming up.

User-facing term is **"Prize Giveaway"** (never "Tap Contest").

## Hard constraint

The indicator must **NOT reveal the exact open time**. No countdown, no timestamp,
no "starts in X" language. The point is anticipation: keep the user listening and
ready to tap without telling them the precise moment. `opensAt` must never reach
any display surface.

## Scope

Two placements:

- **(A) Player page banner** — for the station the user is listening to.
  Copy: `Win a [Prize Name] — coming up on [Station]`. Text-only for v1.
- **(B) Station-list rows + Home page station cards** — a small badge styled like
  the existing LIVE badge, shown **alongside** LIVE (a station running a giveaway
  is also live). Label: `🎁 GIVEAWAY`. Color: purple (distinct from LIVE's
  green/red).

Out of scope for v1: prize image in the banner, an app-wide banner, any countdown
or timing display.

## Existing code this builds on

- `PlayolaRadio/Core/Giveaways/GiveawayCoordinator.swift` — polls the cross-station
  giveaway feed every 30s, currently selects ONE event (prefers `.open`, else the
  soonest `.scheduled`), arms a reveal timer, publishes to `@Shared(.activeGiveaway)`.
- `PlayolaRadio/Models/GiveawayEvent.swift` — `GiveawayStatus`
  (scheduled/open/closed/canceled/unknown); fields include `id` (per-airing event
  id), `stationId`, `giveawayId`, `prizeName`, `opensAt`, `serverTime`, `viewer`.
- `PlayolaRadio/State/SharedUserDefaults.swift` — `@Shared(.activeGiveaway)` holds
  only the current `.open` event. (There is also an unused `@Shared(.giveawayBanner)`
  slot for an app-wide "Tap In" invite; **do not reuse it** — different semantics.)
- `PlayolaRadio/Models/LiveStationInfo.swift` + `@Shared(.liveStations)` — the
  per-station lookup pattern we mirror.
- `PlayolaRadio/Views/Reusable Components/LiveBadge.swift` — the badge to mirror.
- `PlayolaRadio/Views/Pages/PlayerPage/{PlayerPage,PlayerPageModel,GiveawayOverlayModel}.swift`
  — the open-giveaway overlay (only visible when `activeGiveaway.status == .open`
  AND `stationId` matches now-playing).
- `PlayolaRadio/Views/Pages/StationListPage/StationListModel.swift` — already
  subscribes to `$liveStations.publisher` and rebuilds display rows from the
  emitted value.
- `PlayolaRadio/Views/Pages/HomePage/HomePageModel.swift` — `liveStatusForStation(_:)`.

## Architecture

### 1. New shared state

A per-station projection of upcoming (scheduled) giveaways, parallel to `liveStations`:

```swift
struct UpcomingGiveawayInfo: Equatable, Identifiable, Sendable {
  let stationId: String
  let event: GiveawayEvent
  var id: String { stationId }   // keyed by STATION, not event id
}

@Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo>
```

In-memory shared key (like `activeGiveaway`/`liveStations`), not persisted.

**Why a wrapper and not `IdentifiedArrayOf<GiveawayEvent>`:** `GiveawayEvent.id` is
the per-airing event id, not the station id. Keying an identified array by event id
would break per-station lookup. The wrapper keys by `stationId`, matching how
`liveStations` is consumed.

Only `.scheduled` events ever enter this list — one entry per station, the soonest
by `opensAt`. `.open`/`.closed`/`.canceled`/`.unknown` are excluded (an open
contest is owned by the existing tap overlay).

### 2. Coordinator changes (`GiveawayCoordinator.reconcile()`)

**This requires a structural restructure of `reconcile()`, not an insertion.**
Today the function's control flow is, in order:

1. `guard let jwt = auth.jwt` (GiveawayCoordinator.swift:79) — clears
   `activeGiveaway` and returns on auth loss.
2. `guard let stationId = currentPlayolaStationId` (line 84) — returns **before any
   network call** when nothing Playola is playing.
3. `feed = try await api.giveawayEventsFeed(jwt)` (line 91) — only reached when a
   station is playing.

Because the feed fetch sits behind the now-playing guard, simply "inserting after
the fetch" would never populate `upcomingGiveaways` for a user browsing the station
list without anything playing — exactly the case placement B must serve. The
restructure:

- After the **auth** guard (jwt available), fetch the feed and publish the
  all-stations scheduled projection **unconditionally** — do not gate it on
  `currentPlayolaStationId`.
- Only **after** publishing the projection, branch on `currentPlayolaStationId` for
  the existing single-event selection + reveal-timer path (unchanged).

```swift
// runs for any authenticated user, regardless of now-playing
let upcoming = Dictionary(grouping: feed.filter { $0.status == .scheduled }, by: \.stationId)
  .compactMap { stationId, events in
    events.min(by: { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) })
      .map { UpcomingGiveawayInfo(stationId: stationId, event: $0) }
  }
$upcomingGiveaways.withLock { $0 = IdentifiedArray(uniqueElements: upcoming) }

// only now branch on the current station for reveal-timer / single-event work
guard let stationId = currentPlayolaStationId else { return }
// …existing selection + armRevealIfNeeded logic…
```

Four correctness fixes:

1. **Decouple the all-stations projection from now-playing.** Move the feed fetch +
   projection ahead of the `currentPlayolaStationId` guard (line 84) so badges
   populate even when nothing is playing. Only the reveal-timer / single-event path
   keeps consuming `currentPlayolaStationId`.
2. **Clear both on auth loss.** The `auth.jwt == nil` guard (line 79) today clears
   only `activeGiveaway`. The feed fetch requires the jwt, so on auth loss we cannot
   refresh — we must instead **clear `upcomingGiveaways` as well as
   `activeGiveaway`** before returning. Otherwise stale "coming up" badges/banners
   persist after sign-out or token expiry. (The transient feed-fetch failure path
   keeps last-known state and retries — unchanged from today.)
3. **Recompute (not blank) the station's entry whenever `activeGiveaway` is set.**
   When a contest opens, the now-open event must leave `upcomingGiveaways`
   immediately (don't wait up to 30s for the next poll). But because the projection
   is one-soonest-scheduled-per-station, do **not** blindly clear the whole station
   entry — that would hide a *later* scheduled giveaway for the same station until
   the next poll. Instead remove the specific opened event and re-derive that
   station's soonest remaining `.scheduled` entry from the feed snapshot in hand
   (drop the station only if none remains). This fix must apply at **every** site
   that writes a non-nil `activeGiveaway`, not just the timer path:
   `revealEvent` (line 165), the early-open branch in `armAndReveal`
   (`if event.status == .open`, line 309), and `revealFromHeldEvent` (line 337).
   Factor a single helper so all three paths stay consistent.
4. **Feature gate clears both.** When `GiveawayFeature.isLiveDataEnabled` is false,
   clear both `activeGiveaway` and `upcomingGiveaways`.

The existing single-event selection + reveal-timer logic is otherwise untouched.

### 3. Player page banner (placement A)

New small model `UpcomingGiveawayBannerModel` (`@MainActor @Observable`, subclass of
`ViewModel` — the project's canonical base for all page/sub-page models, mirroring
`GiveawayOverlayModel: ViewModel`):

- Reads `@Shared(.upcomingGiveaways)`, `@Shared(.nowPlaying)`, and
  `@Shared(.activeGiveaway)`. The `activeGiveaway` dependency is required: without
  observing it, `isVisible` cannot react to the scheduled→open transition and the
  banner would stay frozen on screen after the tap overlay appears.
- `isVisible`: true when there is an upcoming entry whose `stationId` matches the
  now-playing station AND there is no `.open` `activeGiveaway` for that station.
- `bannerText`: `Win a \(prizeName) — coming up on \(stationName)`. `prizeName`
  comes from the upcoming entry's `event`; `stationName` is derived from
  `nowPlaying?.currentStation`, unwrapping the `.playola(station)` case for
  `station.name` (same pattern `GiveawayOverlayModel.currentStationId` uses for
  `station.id`). The banner only shows for the now-playing station, so this source
  is always available when visible.
- Owns ALL copy (per MV rules). No date formatting, no "soon" computation, never
  references `opensAt`.

Rendered in `PlayerPage.swift` **above** the existing red tap overlay (anticipation
above action). Hosted by `PlayerPageModel` like the overlay model is today.

### 4. Station-list + Home badges (placement B)

New view `UpcomingGiveawayBadge` styled like `LiveBadge` (Inter SemiBold 10pt,
`Color.black.opacity(0.7)` background, 1pt colored stroke, 4pt corner radius, soft
pulse animation). Label `🎁 GIVEAWAY`, color purple.

- **Station list rows:** the row model gets a per-station upcoming flag/event the
  same way it gets `liveStatus`. `StationListModel` subscribes to
  `$upcomingGiveaways.publisher` (mirroring `$liveStations.publisher`) and rebuilds
  rows from the **emitted value** (not stale `self.upcomingGiveaways` — swift-sharing
  publishers emit in `willSet`). The badge renders in the same trailing `HStack` as
  `LiveBadge`, alongside it.
- **Home cards:** add `HomePageModel.upcomingGiveawayForStation(_:)` mirroring
  `liveStatusForStation(_:)`; pass the result into the station card view, which
  renders both badges (LIVE + giveaway) stacked at the top-left of the artwork.

## Lifecycle / reactive correctness

- All consumers observe `@Shared(.upcomingGiveaways)` via the same mechanisms used
  for `liveStations` today — no row-level Combine subscriptions, no polling.
- Sinks that rebuild from a publisher use the emitted value, not `self.<shared>`
  (swift-sharing emits in `willSet`, so `self` is stale inside the sink).
- Scheduled → open: that event removed immediately at every `activeGiveaway` write
  site (fix #3), station's next scheduled event re-derived; overlay takes over.
- Open → closed/canceled, or event drops from feed: next 30s poll re-publishes the
  projection without it.

## Risks (from Codex + PR review)

1. Keying by event id instead of station id breaks lookup → mitigated by the
   `UpcomingGiveawayInfo` wrapper.
2. Coordinator feed fetch is gated behind the now-playing guard → must be
   restructured so the fetch + projection run ahead of that guard, else badges
   never populate while nothing is playing (fix #1).
3. Feed latency (up to 30s) on open/close → mitigated for the opening event by
   removing it from the projection at every `activeGiveaway` write site (fix #3);
   other stations tolerate ≤30s lag.
4. Blanking a whole station entry on open would hide a *later* scheduled giveaway
   for that station → re-derive the soonest remaining `.scheduled` instead of
   clearing the station (fix #3).
5. `opensAt` leaking into the UI → no display model formats dates or computes "soon".
6. Station both LIVE and upcoming → show both badges side by side; never overload LIVE.
7. Banner frozen-visible after reveal → `UpcomingGiveawayBannerModel` must observe
   `@Shared(.activeGiveaway)`, not just `upcomingGiveaways` + `nowPlaying`.
8. Feature gate must clear both shared keys when disabled (fix #4).
9. Do not reuse `@Shared(.giveawayBanner)` — different ("Tap In" invite) semantics.
10. Auth loss (sign-out / token expiry) must clear `upcomingGiveaways`, not just
    `activeGiveaway` — otherwise stale "coming up" badges linger (fix #2).

## Testing

- `GiveawayCoordinator`: feed with mixed statuses across multiple stations →
  `upcomingGiveaways` contains exactly one `.scheduled` entry per station (soonest),
  excludes open/closed/canceled/unknown; projection populates with no now-playing
  station; on reveal the opening event leaves the projection and the station's next
  scheduled event (if any) is re-derived rather than the station being blanked;
  feature-gate-off clears both keys; **auth loss (`auth.jwt == nil`) clears both
  `activeGiveaway` and `upcomingGiveaways`**. (Use `@Shared` declared locally per
  test, swift-dependencies mocked via `withDependencies`.)
- `UpcomingGiveawayBannerModel`: `isVisible` true only for matching now-playing
  station with no open contest; `bannerText` correct (prize + station name); hidden
  once that station's contest is open (verifies the `activeGiveaway` observation).
- `StationListModel` / `HomePageModel`: per-station lookup returns the right
  upcoming event; rows/cards reflect add/remove reactively.
- Assert with `expectNoDifference` / `expectDifference` (CustomDump), not raw `==`.

## Out of scope (possible follow-ups)

- Prize image in the player banner.
- Glow/border accent on station cards (badge only for v1).
- App-wide banner.
