# Koozie-Only Rewards Experience for New Users — Design (v2)

**Date:** 2026-08-10
**Branch:** `briankeane/koozie-only-rewards`
**Status:** Design approved by user. Server endpoints shipped. Ready for architecture + plan.
**Supersedes:** `2026-08-08-koozie-only-rewards-design.md` (that version assumed a server
auto-award + `koozieRequiredHours` on the profile; the server actually shipped a
**user-initiated redeem with an inline shipping-address capture**, threshold from `/tiers`,
koozie identified by `slug`).

## Overview

New users (server-designated cohort) get a stripped-down rewards experience: instead of
the full multi-tier "Listener Rewards" page, they can only earn a **Koozie**. Progress
toward it, claiming it (with a US shipping address), a one-time congrats, and a quiet
earned state all live **inline on the Home screen's existing Listening Time tile**. For
these users the Rewards page and the Profile "Rewards" button are removed.

Existing ("full-tiers") users are **completely unchanged**.

This is a **client-reads / server-owns** design: the server owns cohort assignment, the
koozie threshold, earning/claim, fulfillment, and the congrats email. The client reads
that state and renders it; it never invents or locally persists reward state. Every new
server field is optional — **absent ⇒ exactly today's behavior**, so `develop` stays
deployable even if the client ships before (or without) the server.

## Cohort & data sources

- **Cohort flag:** `RewardsProfile.rewardsExperience: String?` (new, self-only). Parsed to
  an enum with a conservative fallback:

  ```swift
  enum RewardsExperience: Equatable {
    case fullTiers   // absent / null / ANY unrecognized value
    case koozieOnly  // "koozie_only"
  }
  ```

  Unknown string ⇒ `.fullTiers` (never koozie-only), per the repo's "server enums need a
  safe unknown fallback" rule.

- **Threshold + koozie identity:** from the existing public `GET /v1/rewards/tiers`. Each
  `Prize` now carries `slug: String?`. Find the prize with `slug == "koozie"`; take its
  `id` (the `prizeId` for redeem) and its tier's `requiredListeningHours` (the threshold —
  50 today; **read it, don't hardcode**). No hardcoded UUID.

- **Earned / congrats:** `RewardsProfile.koozieEarned: Bool?` and
  `RewardsProfile.shouldShowKoozieCongrats: Bool?` (new, self-only, koozie-cohort only).
  `koozieEarned` is true once claimed and stays true after congrats is dismissed;
  `shouldShowKoozieCongrats` is true only while earned AND the in-app congrats has not been
  dismissed.

- **Prize name (congrats copy):** the koozie `Prize.name` from `/tiers`. Congrats reads
  "You've earned a {prizeName}! Thanks for listening!".

All koozie state rides on the already-fetched `listeningTracker.rewardsProfile`
(`MainContainerModel.loadListeningTracker`). **No new durable `@Shared` koozie flag** — the
profile is the single source of truth (survives reinstall / second device).

## Live counter (unchanged calculation)

Progress and the redeem-enable threshold reuse the tile's **existing live counter**,
`listeningTracker.totalListenTimeMS` (= local sessions + server `totalTimeListenedMS`),
already computed and ticking every second in `ListeningTimeTileModel`. No new calculation.

## State machine

One derived `ListeningTimeTileMode`, owned by the tile **model** (the SwiftUI view stays
logic-free and just renders the header counter + a mode-driven bottom section):

| Mode | Condition | Bottom section |
|---|---|---|
| `.legacyRewards` | not `.koozieOnly` | **unchanged** — live counter + "Redeem Your Rewards!" button |
| `.koozieInProgress(hoursRemaining, progress)` | koozie, `!koozieEarned`, live hrs `<` threshold | koozie icon · "Playola Koozie" · "Xh Ym of listening to go" · "NN%" + progress bar |
| `.koozieClaimable` | koozie, `!koozieEarned`, live hrs `≥` threshold | "You earned a koozie!" + **Redeem your koozie** button (no ✕) |
| `.koozieAddressForm` | *(client-only sub-state of Claimable)* | "Where should we send it? · US addresses only. We'll only use this to ship your koozie." + address fields + **Back** / **Send my koozie** |
| `.koozieCongrats` | koozie, `koozieEarned`, `shouldShowKoozieCongrats` | "You've earned a {prizeName}! Thanks for listening!" + **✕ dismiss** |
| `.koozieEarned` | koozie, `koozieEarned`, `!shouldShowKoozieCongrats` | quiet row: "Koozie redeemed — check your email" |

Notes:
- **Distance/percent are live** off the local counter (smooth countdown); the **earned
  flip is server-authoritative** (only changes after a successful claim + profile refetch).
- **Claimable → Congrats are two separate states**, not one card. The ✕ (dismiss) calls
  `koozie-congrats-seen`, which the server rejects with **409 KOOZIE_NOT_EARNED** before a
  claim — so a dismiss is only offered post-claim. Redeem (button) and dismiss (✕) act on
  different server states.
- **Address form is client-only UI state** entered by tapping "Redeem your koozie" and
  left via "Back" (→ Claimable) or "Send my koozie" (→ submit). Backgrounding without
  submitting returns to Claimable on next launch (`koozieEarned` still false).
- There is **no "pending verification" state** (the old spec's server-auto-award lag): the
  earned flip is caused by the user's own claim, so the only transient is the in-flight
  submit, shown as a busy state on "Send my koozie".

## Actions

### Redeem (Send my koozie)
`POST /v1/rewards/users/me/prizes/{kooziePrizeId}/redeem`

Body:
```json
{
  "shippingAddress": {
    "fullName": "…",       // required
    "addressLine1": "…",   // required
    "addressLine2": "…",   // optional (omit when empty)
    "city": "…",           // required
    "state": "TX",         // required, 2-letter US code (server uppercases)
    "postalCode": "78704"  // required, ##### or #####-####
                           // country omitted (server defaults to "US")
  }
  // stationId omitted for the koozie
}
```
**API design (locked):** a **new** `redeemKooziePrize(jwt, prizeId, address)` client
method (do **not** overload the station-shaped `redeemPrize`), with a typed
`KoozieShippingAddress: Encodable` body built via a manual `serializingData().response`
path (the generic `[String:String]` helpers can't express the nested JSON and discard the
error body). HTTP handling lives **inside the live dependency closure** — models never
inspect `AFError`:
- **201** → claimed; server sends the congrats email. Response is the `UserPrize` (with the
  address snapshot); the client does not read it — it re-fetches the profile.
- **409** ("Prize already redeemed", incl. concurrent double-tap) → **caught in the
  dependency and returned as success** (idempotent). Re-fetch profile.
- **400** (missing/invalid address or bad UUID) → dependency throws
  `APIError.validationError(serverMessage)` (parsed from `error.message`); the model shows
  it inline on the form and keeps the form open. (Client validates ZIP `#####`/`#####-####`
  first for a nicer message.)
- On success (201 or 409) → **re-fetch profile** → `koozieEarned: true`,
  `shouldShowKoozieCongrats: true` → drives `.koozieCongrats`.

Field mapping (form → body): Full name → `fullName`, Street address → `addressLine1`
(+ optional line 2 → `addressLine2`), City → `city`, State → `state`, ZIP → `postalCode`.

### Dismiss congrats (✕)
New `markKoozieCongratsSeen(jwt)` void POST →
`POST /v1/rewards/users/me/koozie-congrats-seen` (no body; mirrors `welcome-message-seen`).
- **204** → recorded (write-once + idempotent).
- 409 KOOZIE_NOT_EARNED / other → **tolerated as success inside the dependency** (we only
  offer ✕ in `.koozieCongrats`, so this is defensive).
- Optimistically drop to `.koozieEarned`; reconcile on the next profile fetch
  (`shouldShowKoozieCongrats: false`).

### Profile refresh preserving local sessions
After redeem/dismiss the client must refresh the rewards profile to pick up the new flags.
Today's `loadListeningTracker` rebuilds `ListeningTracker(rewardsProfile:)` with an **empty**
`localListeningSessions`, which would visibly jump the live timer backward mid-session.

**Mechanism (locked):** add a preservation primitive on `ListeningTracker`, e.g.
`replacingRewardsProfile(_ profile:) -> ListeningTracker`, that carries over the current
`localListeningSessions`. Use it from **both** `MainContainerModel.loadListeningTracker`
(fixing the existing reset at `MainContainerModel.swift:255`) and the koozie redeem/dismiss
refresh. **Snapshot the sessions at assignment time — after the network await, not before**
— so a slow profile fetch can't overwrite sessions accrued while it was in flight. All
writes are on the main actor; the 1s loop only reads `totalListenTimeMS`, so main-actor
replacement of the shared tracker is safe.

## Removals for koozie users

- **Home tile:** no "Redeem Your Rewards!" button (the koozie sections replace it).
- **Profile (Contact) page:** hide the "Rewards" button — model exposes
  `showRewardsButton: Bool` (false for koozie-only); the view stays control-flow-free.
- **Guard the route at the coordinator, not just the button** (locked): hiding buttons +
  no-op `onRewardsTapped` is cosmetic — restored nav state or a stray push can still land on
  `.rewardsPage`, which renders unconditionally today
  (`MainContainerNavigationCoordinator.swift:90`). Guard the push/append entry points for
  `.rewardsPage` and **sanitize the existing profile path** (drop any `.rewardsPage`
  entries) when a koozie-only profile loads. The route + model stay in code, just
  unreachable for this cohort.

Full-tiers users: **zero change** to Home, Profile, Rewards page, or the tile.

## Address form (inline in the tile)

Per the mockup the form is **inline in the Listening Time tile** (not a sheet), rendered
below the live counter in `.koozieAddressForm`.

- Fields (all trimmed): Full name, Street address, (optional) address line 2, City, State
  (2-letter), ZIP. US-only helper copy.
- **Model owns validation & enablement:** "Send my koozie" enabled only when required
  fields are non-empty and ZIP matches `^\d{5}(-\d{4})?$`. Field values are model state
  exposed as bindings; the view has no logic.
- "Back" returns to `.koozieClaimable` (fields retained in-session is fine).
- Keyboard/scroll: the tile lives on the Home scroll view; ensure the form is reachable
  above the keyboard (implementation detail; no design impact).

## Model ownership (locked in architecture pass — Codex consult 2026-08-10)

- **`ListeningTimeTileModel` stays thin.** It keeps its existing 1s live-counter loop and
  legacy button behavior **byte-for-byte unchanged**, and only gains a selector between
  `.legacy` and `.koozie(KoozieTileModel)`. Do **not** fatten it into a rewards workflow
  object, and do **not** have a parent (Home) inject the mode (that would move reward
  derivation + timing into the page). This keeps the reusable tile reusable.
- **`KoozieTileModel` (new, `@Observable`)** owns the koozie concerns: mode derivation
  (from `rewardsExperience` / `koozieEarned` / `shouldShowKoozieCongrats` / live hrs vs
  threshold), **all** koozie copy + progress values, the redeem / dismiss / profile-refresh
  actions, and the tiers lookup (`slug == "koozie"` → `prizeId` + `requiredListeningHours`).
  It holds `@Dependency(\.api)`, `@Shared(.auth)`, `@Shared(.listeningTracker)`.
- **`KoozieAddressFormModel` (new, nested `@Observable`)** owns the form: bindable fields
  (fullName / addressLine1 / addressLine2 / city / state / postalCode), trimming, ZIP
  validation, `canSubmit`, the trimmed `KoozieShippingAddress` payload, and the inline
  server-error string. Keeps the tile model out of "junk-drawer" territory.
- The `ListeningTimeTile` **view** renders header + a mode-driven bottom section and binds
  to the form fields only — no logic.
- **`ContactPageModel`** gains read access to `rewardsExperience` (via
  `listeningTracker.rewardsProfile`) to drive `showRewardsButton`.

## Backward compatibility & sequencing

- **Client before/without server fields:** `rewardsExperience` absent ⇒ `.fullTiers` ⇒
  today's behavior exactly; missing `koozieEarned` / `shouldShowKoozieCongrats` / `slug`
  tolerated as nil. `develop` stays deployable at every step.
- **Client after server:** all new behavior gated solely on `rewardsExperience ==
  .koozieOnly`. Server endpoints are already live.

## Testing

swift-testing, `@MainActor`, `@Suite(.freshSharedState)`; mock via `withDependencies`;
`expectNoDifference` for value comparisons. (See CLAUDE.md testing rules + pfw-testing /
pfw-custom-dump.)

- Cohort decode: absent ⇒ `.fullTiers`; `"koozie_only"` ⇒ `.koozieOnly`; unknown ⇒
  `.fullTiers`.
- `Prize.slug` decodes (present / absent → nil). Koozie lookup by slug picks the right
  `prizeId` + tier `requiredListeningHours`.
- Tile mode derivation: each mode from representative inputs, including the
  claimable boundary (live hrs crossing threshold with `koozieEarned == false`).
- Address form: "Send my koozie" enablement (required fields, ZIP regex); Back returns to
  Claimable.
- Redeem: builds the correct body from form fields; 201 → refetch → `.koozieCongrats`;
  **409 treated as success** → refetch; 400 surfaces the server message inline and keeps
  the form open.
- Dismiss: optimistic hide + calls `koozie-congrats-seen`; reconciles when the profile
  returns `shouldShowKoozieCongrats == false`.
- Profile refresh preserves `localListeningSessions` (live counter not reset).
- `ContactPageModel.showRewardsButton` false for koozie-only, true otherwise; `.rewardsPage`
  route inert for koozie-only.
- Backward compat: all new fields absent ⇒ Home / Contact / Rewards behave exactly as today.

## Out of scope

- Any change to the three-tier experience for existing users.
- Server implementation (already shipped: redeem-with-address, `koozie-congrats-seen`,
  profile cohort fields, `slug` on prizes).
- `LONG_RUNNING.md` soak tracking (not tracked there; single-PR iOS change).
- Collecting anything beyond the US shipping address; non-US addresses.
</content>
</invoke>
