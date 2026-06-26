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

After the existing feed fetch, publish the all-stations scheduled projection:

```swift
let upcoming = Dictionary(grouping: feed.filter { $0.status == .scheduled }, by: \.stationId)
  .compactMap { stationId, events in
    events.min(by: { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) })
      .map { UpcomingGiveawayInfo(stationId: stationId, event: $0) }
  }
$upcomingGiveaways.withLock { $0 = IdentifiedArray(uniqueElements: upcoming) }
```

Three correctness fixes:

1. **Decouple the all-stations projection from now-playing.** Today the coordinator
   exits early when there is no current Playola station — which would leave
   station-list/Home badges stale or empty. The upcoming-giveaways projection must
   be published from the full feed regardless of what (if anything) is playing.
   Only the reveal-timer path needs `currentPlayolaStationId`.
2. **Immediate removal on reveal.** When the reveal timer fires and publishes the
   `.open` event to `activeGiveaway`, also remove that station's entry from
   `upcomingGiveaways` in the same step, so the banner/badge disappears instantly
   instead of waiting up to 30s for the next feed poll.
3. **Feature gate clears both.** When `GiveawayFeature.isLiveDataEnabled` is false,
   clear both `activeGiveaway` and `upcomingGiveaways`.

The existing single-event selection + reveal-timer logic is otherwise untouched.

### 3. Player page banner (placement A)

New small model `UpcomingGiveawayBannerModel` (`@MainActor @Observable`, mirrors
`GiveawayOverlayModel`):

- Reads `@Shared(.upcomingGiveaways)` and `@Shared(.nowPlaying)`.
- `isVisible`: true when there is an upcoming entry whose `stationId` matches the
  now-playing station AND there is no `.open` `activeGiveaway` for that station.
- `bannerText`: `Win a \(prizeName) — coming up on \(stationName)`.
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
- Scheduled → open: badge/banner removed immediately by the reveal step (fix #2),
  overlay takes over.
- Open → closed/canceled, or event drops from feed: next 30s poll re-publishes the
  projection without it.

## Risks (from Codex review)

1. Keying by event id instead of station id breaks lookup → mitigated by the
   `UpcomingGiveawayInfo` wrapper.
2. Coordinator fetch gated on now-playing → must be split so the projection runs
   regardless (fix #1).
3. Feed latency (up to 30s) on open/close → mitigated for the current station by the
   immediate-removal-on-reveal step (fix #2); other stations tolerate ≤30s lag.
4. `opensAt` leaking into the UI → no display model formats dates or computes "soon".
5. Station both LIVE and upcoming → show both badges side by side; never overload LIVE.
6. Feature gate must clear both shared keys when disabled (fix #3).
7. Do not reuse `@Shared(.giveawayBanner)` — different ("Tap In" invite) semantics.

## Testing

- `GiveawayCoordinator`: feed with mixed statuses across multiple stations →
  `upcomingGiveaways` contains exactly one `.scheduled` entry per station (soonest),
  excludes open/closed/canceled/unknown; projection populates with no now-playing
  station; reveal removes the current station's entry immediately; feature-gate-off
  clears both keys. (Use `@Shared` declared locally per test, swift-dependencies
  mocked via `withDependencies`.)
- `UpcomingGiveawayBannerModel`: `isVisible` true only for matching now-playing
  station with no open contest; `bannerText` correct; hidden once that station's
  contest is open.
- `StationListModel` / `HomePageModel`: per-station lookup returns the right
  upcoming event; rows/cards reflect add/remove reactively.
- Assert with `expectNoDifference` / `expectDifference` (CustomDump), not raw `==`.

## Out of scope (possible follow-ups)

- Prize image in the player banner.
- Glow/border accent on station cards (badge only for v1).
- App-wide banner.
