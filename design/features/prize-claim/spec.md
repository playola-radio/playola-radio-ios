# Prize Claim — in-app collection of prize fulfillment info

**Target surface:** ios (consumes existing playola backend endpoints; no backend changes)
**Base commits:** playola-radio-ios `20417ae34c60762e5fec18f7603877dae9aac78b` (origin/develop) ·
playola `1e1b57b8ee67521fa192a9b190f51184c66dc625` (origin/develop)
**Server contract:** playola `design/features/merch-fulfillment/contracts.md` §B,
`server/src/api/fulfillmentRequests/ENDPOINTS.md`, `server/src/api/rewardRedemptions/ENDPOINTS.md`

## Scope

When a user wins or earns a prize, the app collects whatever info that prize needs (address, shirt
size, guest-list name, …) up front, in-app, from a form rendered generically from the server's
`infoFields`. If they defer, a Home tile lets them finish later.

1. **Claim sheet (one, reused everywhere).** Congrats header (prize image + title) → form generated
   from the fulfillment request's `infoFields` (SHORT_TEXT → text field, MULTI_LINE_TEXT → text area,
   SINGLE_CHOICE → choice control, ADDRESS → US address block) → Submit (`PUT
   /v1/fulfillment-requests/:id/answers`) / Later. A request with no required fields shows congrats +
   Done only.
2. **Giveaway win.** Replaces today's email-only `GiveawayWinnerSheetView`. The request is located via
   `GET /v1/users/me/fulfillment-requests` by `giveawayEventId`. The app stops calling
   `POST /v1/giveaway-events/:eventId/winner-submission`.
3. **Koozie (koozie-only cohort).** On crossing the listening threshold, present the claim sheet up
   front. Claim → `POST /v1/users/me/reward-redemptions` → form in the same sheet using the returned
   request. The Home prize tile is the only claim entry point: the Listening tile's Redeem button
   and the inline koozie address form (in `KoozieTileSection`) are removed, and the tile instead points at the prize tile
   (see approvals log 2026-10-02); "check your email" copy is removed (endpoint 4 sends no email).
4. **Legacy-tier rewards (Rewards page).** Redeem → `POST /v1/users/me/reward-redemptions` → claim
   sheet. Replaces the email-only `RedeemPrizeSheetView` and the legacy redeem call. No up-front
   presentation (the user already initiated it).
5. **Home tiles.** One `NewFeatureTile` per `awaiting_info` request plus one for an earned-but-unclaimed
   koozie, in the server's order with the koozie last; each opens the claim sheet.
6. **Show-once rule.** The up-front sheet is presented once per prize (giveaway win / koozie threshold).
   After "Later" the Home tile is the only re-entry. This replaces today's re-present-every-foreground
   behavior for giveaway winners.
7. **Analytics.** Claim sheet shown / later / submitted / submit error; prize tile shown / tapped.

## Non-goals

- Showing shipping status / tracking to the user (a `ready_to_ship` request's tile simply disappears).
- Editing answers after submission.
- Push deep links by fulfillment-request id (the server's win push carries no request id; the list
  endpoint is the discovery path).
- Non-US addresses.
- Any backend change.

## Open questions

- ~~Server deploy dependency~~ — resolved 2026-10-05: the fulfillment migrations ran in production
  2026-10-04 (requests exist for 28 `awaiting_info` users: 13 koozie, 15 giveaway).
- ~~Where "already presented" is tracked~~ — resolved in models.md: giveaway wins reuse
  `GiveawayParticipation.winnerSheetPresentedAt`; the koozie uses a per-account device-local
  `@Shared(.koozieClaimPromptShownUserIds)`.

## Release prerequisite (data, not code)

- **Configure `infoFields` for Show Tix and Meet & Greet** in production (admin tool) before this app
  release ships. Today both have `[]`, so a redemption goes straight to `ready_to_ship` with nothing
  collected — and the new redemption path sends no email, so nothing else collects it either. Brian
  decides the fields. Koozie already has its required ADDRESS field.

## Background — why (2026-10-02 investigation)

The koozie-only cohort (users created ≥ 2026-09-01, 262 in prod) has had an in-app address form inside
the Home Listening tile since v7.6.0, but the *only* signal that a koozie is claimable is that tile
changing state — no sheet, push, or badge, and no analytics. One user (`270ae987…`) crossed the 50h
threshold on 2026-09-24, is on 7.6.0, listens daily (76.1h), and has not claimed. No defect was found
in the data path (`/v1/rewards/tiers` returns the `koozie` slug at 50h; server profile total ≈ 76h), so
the likely cause is discoverability. Giveaway winners, by contrast, get a sheet re-presented on every
foreground until they submit.

## Existing contracts

### Screens (current app)

Canvas (`design/playola-ios.pen`, "Current App · Listener"): `Home` (`M8XBj`) and the reusable
`Feature Tile` (`hwShQ`) — ![home](exports/existing/home.png) ![feature tile](exports/existing/feature-tile.png).
The three prize surfaces this feature replaces exist only in code, not on the canvas:

| Surface | File | What it does today |
|---|---|---|
| Giveaway winner sheet | `Views/Pages/GiveawayWinnerSheet/GiveawayWinnerSheetView.swift` | Prize image 160pt, "You won" headline (Space Grotesk 26), prize name/description, single Email field, "Claim Prize" → claimed state "Congrats!" / Done. Re-presented every foreground until submitted. |
| Koozie in Listening tile | `Views/Reusable Components/ListeningTimeTile/KoozieTileSection.swift` | Progress → "You earned a koozie!" + "Redeem your koozie" → inline address form ("Where should we send it?", US only, "Send my koozie") → "Koozie redeemed — check your email". |
| Legacy reward redeem | `Views/Pages/RewardsPage/RedeemPrizeSheetView.swift` | "Redeem Reward" sheet: choose prize + "Email for follow-up" → Redeem. |

### Endpoints the app calls today (affected)

| Call | Endpoint | Fate |
|---|---|---|
| `redeemPrize` | `POST /v1/rewards/users/me/prizes/:prizeId/redeem` | Replaced by `POST /v1/users/me/reward-redemptions` |
| `redeemKooziePrize` | `POST /v1/rewards/users/me/prizes/:prizeId/redeem` (with address body) | Replaced by reward-redemptions + answers PUT |
| `submitGiveawayWinnerDetails` | `POST /v1/giveaway-events/:eventId/winner-submission` | Replaced by answers PUT |
| koozie congrats seen | `POST /v1/rewards/users/me/koozie-congrats-seen` | Review in Phase 4 (may overlap the show-once rule) |
| `getPrizeTiers`, rewards profile, `GET /v1/rewards/users/me/prizes` | unchanged | Still drive the koozie threshold + Rewards page |

### New endpoints consumed (server contract, on playola `develop`)

`GET /v1/users/me/fulfillment-requests` → `FulfillmentRequestSummary[]` (`awaiting_info` + `ready_to_ship`,
newest first) · `GET /v1/fulfillment-requests/:id` · `PUT /v1/fulfillment-requests/:id/answers`
(`{infoAnswers}` merged per key, `""` clears, unknown key 400, 409 when fulfilled/canceled, returns
summary, auto-moves to `ready_to_ship` when all required answers present) · `POST
/v1/users/me/reward-redemptions` (`{prizeId, stationId?}` → 201 summary; 409 `PRIZE_ALREADY_REDEEMED`).
Full shapes are written up in `endpoints.md` / `models.md` (Phase 4).

### Form ↔ server validation check (2026-10-05, playola `origin/develop`)

Checked against `server/src/lib/infoFields/infoFields.lib.ts` (`mergeInfoAnswers`) and
`server/src/lib/shipping/shipping.lib.ts` (`validateUsShippingAddress`). The approved form matches;
these client rules follow from it (full contract goes in `models.md`/`endpoints.md`, Phase 4):

- **ADDRESS** answer is one object `{fullName, addressLine1, addressLine2?, city, state, postalCode,
  country?}`, validated whole — a partial address fails the entire PUT with a generic 400
  (`SHIPPING_ADDRESS_INVALID`, no per-field detail). The client must validate before sending.
- **State** must be one of the server's `US_STATE_CODES` (50 states + DC, PR, VI, GU, AS, MP, AA,
  AE, AP); send the 2-letter code. The State picker lists exactly that set.
- **ZIP** must match `^\d{5}(-\d{4})?$`. The number pad can't type "-", so the client accepts exactly
  5 digits; a malformed ZIP keeps the sheet in the Incomplete state with hint "Enter a 5-digit ZIP
  code."
- **SHORT_TEXT** ≤ 255 chars, **MULTI_LINE_TEXT** ≤ 5000, address text fields ≤ 255 — cap input
  client-side.
- **SINGLE_CHOICE** answer must equal one of `options` exactly.
- Server trims and treats whitespace-only as unanswered — client "required" checks trim too.
- `country` is omitted (server defaults it to "US").
- A 400 that still slips through shows the Send failed state with "Some of your answers didn't go
  through. Check them and try again." instead of the connection copy.

## Adversarial review (Phase 5, Codex, 2026-10-05)

Codex reviewed spec + screens + endpoints + models (13 findings). No finding is blocking. Dispositions
(confirmed with Brian 2026-10-05):

| # | Finding | Disposition |
|---|---|---|
| 1 | Server backfill drops legacy koozie/winner addresses into `awaiting_info` | **Accepted with rationale** — server-design concern, moot in prod: the one koozie with a legacy address is already `ready_to_ship` with answers; the 13 + 15 `awaiting_info` users getting a tile is intended. No server change. |
| 2 | Show Tix / Meet & Greet have empty `infoFields`; with no email, nothing collects their info | **Resolved** — release prerequisite above. |
| 3 | Two devices / operator + user editing the same request | **Accepted** — last-write-wins; the app sends only fields with a value, never `""`, so it can't clear another writer's answer (endpoints.md PUT). |
| 4 | Who owns "claimed" state after a POST | **Resolved** — the claim result is reported to the opener: Rewards marks the tier; the koozie keeps a local claimed override until the profile shows `koozieEarned` (endpoints.md POST). |
| 5 | PUT returns a different shape for admin callers | **Resolved** — the PUT response is not decoded; any 2xx = success, then refetch. |
| 6 | Error handling relies on symbolic names not on the wire; 401 unspecified | **Resolved** — branch on HTTP status only via `ClaimAPIError`; 401 takes the generic failure path (no app-wide re-auth exists). POST 403/404 → No longer open. |
| 7 | Fulfillment status vs `GiveawayParticipation` disagree | **Resolved** — server status is authoritative; wins whose sheet an older build already showed get the tile only; a `ready_to_ship` match shows Nothing to fill in. |
| 8 | Up-front presentation races (push vs foreground, giveaway vs koozie, sheet slot busy) | **Resolved** — implementation rules (plan): single-flight presentation; re-check the sheet slot after every await; giveaway before koozie; koozie threshold checked on foreground / Home appear; present only into a free slot (giveaway: empty or the Player sheet, as today; koozie: empty only); no swipe-dismiss while Loading / Sending; the Choice picker is local to the Claim sheet, not a `PlayolaSheet` case. |
| 9 | Device-wide koozie marker leaks across accounts | **Resolved** — keyed per user id (models.md). |
| 10 | Validation gaps | **Resolved** — exact SINGLE_CHOICE values; optional ADDRESS all-or-nothing; length caps counted in UTF-16 (server's JS `length`); a pre-filled ZIP+4 stays valid. |
| 11 | Tier → prize mapping for Rewards "Redeem" | **Resolved** — the tier's single prize; a tier with no prize hides Redeem (screens.md § Rewards page). |
| 12 | "Newest first" not derivable (createdAt not serialized) | **Resolved** — server order, koozie tile last. |
| 13 | List failure / No longer open / lost 201 conflate states | **Resolved** — Home keeps last-known tiles on failure; refetch after No longer open; POST 409 = claimed, dismiss, refetch. |
| — | Unknown `InfoField` type | **Accepted** — best effort as SHORT_TEXT; the server may 400 (models.md). |

Acceptance scenarios raised by the review are carried into `implementation-plan.md`.

## Simplicity gate (Phase 7, Codex + Claude Opus, 2026-10-05)

Both reviewers read the plan against the real code at `20417ae3`. Neither found a materially simpler
whole-feature approach: one generic sheet replacing the three existing flows is already the
consolidation. Individual cuts, applied in one wave to `implementation-plan.md` (and to models.md /
endpoints.md where the contract text changed):

| Cut | Flagged by | Disposition |
|---|---|---|
| Home prize-tile object cache (kept only for `ForEach(id: \.self)`) — it also froze each tile's action on stale answers | both | **Adopted** — tiles rebuilt from state on every read; `ForEach` keyed by position (`NewFeatureTile` holds no view state) |
| `stubClaimableKoozieForTesting()` DEBUG hook in app code | both | **Adopted** — `HomePageTests` fixture drives the real cohort path (`refreshFromTracker`) |
| Optional-only form exception (contradicted Scope §1) | both | **Adopted** — form iff `awaiting_info` and any required field; else Nothing to fill in |
| Opacity/height visibility helpers duplicating `ClaimSheetContent`'s phase switch | Codex | **Adopted** — the reusable `ClaimSheetContent` switches on phase |
| `GiveawayParticipation.wasPromotedWin` + its 2 tests (only reader is the deleted winner sheet) | Codex | **Adopted** |
| `ClaimAPIError` per-endpoint 409 cases | Claude | **Adopted** — one `init(status:)`; `409 → .conflict`, interpreted by the caller |
| `FulfillmentRequest.Status` `fulfilled` / `canceled` (the list never returns them) | Claude | **Adopted** — `awaitingInfo`, `readyToShip`, `unknown` |
| Redundant status clause when matching a win's request | Claude | **Adopted** — match on `giveawayEventId` only |
| Hand-written memberwise inits | Claude | **Adopted** — `init(from:)` in extensions so Swift synthesizes them |
| `HomePageModel.refreshPrizeRequests()` wrapper + a duplicate list-failure test | Claude | **Adopted** — call the shared refresher; failure pinned once in the refresher's tests |
| Over-limit flag + error copy for text length | Claude | **Adopted** — input clamps at the server limit (UTF-16) |
| Free `incompleteHint(for:)` + separate Later-button helpers | Claude | **Adopted** — one `incompleteHintText` and one `isLaterAvailable` on the sheet model |
| Redemption 400 "check your answers" copy (no answers exist yet) | Claude | **Adopted** — connection copy + `reportIssue` |
| Replace chips / inline list / picker with one `Picker(.menu)` | Claude | **Rejected** — reverses the approved SINGLE_CHOICE rule and visuals; fields are server-configured (shirt sizes are realistic) |
| Drop `RedemptionStatus.unavailable` (tier with no prize) | Claude | **Rejected** — small gain; reverses the approved Phase-5 #11 disposition |

Load-bearing (both reviewers kept): the shared request list + refresher, sign-out clear, per-user
prompt marker, the koozie local "claimed" override, lossy answer decoding, single-flight + post-await
slot re-check, analytics, `requiredHours`. No approved visual changed.

## Design deliverables

- Screens: [screens.md](./screens.md)
- Endpoints: [endpoints.md](./endpoints.md) (app consumption only — no server endpoint changes)
- Models: [models.md](./models.md) (app-side models only — no server model changes)

## Approvals log

- 2026-10-02 — Scope approved in chat (revision: this file's Scope/Non-goals as first written).
  Decisions: covers giveaway + koozie + legacy tiers (option C); single sheet with congrats + inline
  form (A); koozie threshold sheet + analytics added; show-once then tile (A); one Home tile per prize
  incl. unclaimed koozie (A); 2 layout directions for the claim sheet.
- 2026-10-02 — Claim-sheet layout direction **A · One Scrolling Form** (`VVL5Q`) chosen over B ·
  Stepped (`xpCBJ`/`hGXhL`/`pu8xo`, kept on canvas as rejected).
- 2026-10-02 — No-image header: **Icon Tile** (`mVAud` — purple gift tile in the image slot) chosen
  over Collapsed (`ZREPo`). Prize `imageUrl` is often null. Open: SINGLE_CHOICE rendering by option
  count (proposal `K4D70` chips / `tp5TU` inline list / `S28a1a` + `r3ZvbY` picker).
- 2026-10-02 — Codex refinement pass applied directly on the canvas (at Brian's direction): address
  State is now a picker row (chevron), "United States only", picker sheet uses a close (✕) control,
  title sizes normalized, choice-rule captions reworded. Codex recommends Collapsed over Icon Tile for
  no-image — conflicts with the Icon Tile decision above; pending Brian's call.
- 2026-10-02 — **Reversal:** no-image header is **Collapsed** (`ZREPo`: no placeholder, "YOU WON" pill
  + larger title; real image shown above the pill only when `imageUrl` is present). Icon Tile
  (`mVAud`) rejected.
- 2026-10-02 — SINGLE_CHOICE rendering rule approved (deterministic from `options`):
  2–5 options and every label ≤ 4 characters → segmented chips (`K4D70`; always one row spanning the
  full form width, chips equal width with a fixed 8pt gap, 44pt tall); otherwise ≤ 6 options →
  inline single-selection list (`tp5TU`); 7+ options → disclosure row (`S28a1a`) opening a picker
  sheet (`r3ZvbY`, close ✕), with a search field only when > 12 options. Optional fields: tapping the
  selected chip/row deselects; the picker shows a "None" row only when the field is optional.
  Implementation notes from that pass: native Picker/selection semantics where possible; VoiceOver
  reads the selected value; address fields use autofill `textContentType`s; ZIP uses the number pad.
- 2026-10-02 — **Claim sheet approved** (10 states, `screens.md` § Claim sheet): Form with image
  (`eiTMx`), Form no image (`kiqOK`), Reward not yet claimed (`Upib6`), Loading (`vNp75`), Incomplete
  (`Py5xL`), Sending (`P0ErfC`), Send failed (`u7f7m`), No longer open (`Kv6L0`), Nothing to fill in
  (`n2xDx4`), Sent (`yS1Dw`); plus the approved choice-field variants (`wGxLF`, `K4D70`, `tp5TU`,
  `S28a1a`) and the Choice picker (`r3ZvbY`). Swipe-down = Later.
- 2026-10-02 — **Home approved** (`screens.md` § Home): One prize (`Xr7bh`), Several prizes (`UdaDn`);
  prize tiles reuse `NewFeatureTile` unchanged, above other feature tiles, newest first.
  **Scope change (at Brian's direction):** the Home prize tile is the only koozie claim CTA — the
  Listening tile's "Redeem your koozie" button is removed (supersedes Scope §3's "Listening tile's
  Redeem button opens the same sheet"). Implementation note: Home's `ForEach(…, id: \.label)` must
  key prize tiles by a stable id (two "You won" tiles would collide).
- 2026-10-05 — **Listening tile approved** (`screens.md` § Listening tile): Earned, not claimed
  (`GWKZh`), Claimed (`wtGs8`). The post-claim koozie congrats card is dropped (the claim sheet's Sent
  state replaces it); whether the app can stop calling `koozie-congrats-seen` is settled in Phase 4.
- 2026-10-05 — **Rewards page approved** (`screens.md` § Rewards page): visually unchanged; "Redeem"
  opens the Claim sheet in Reward · Not Yet Claimed → `POST /v1/users/me/reward-redemptions` without
  `stationId` → form. `RedeemPrizeSheetView` (email field + station picker) and the `.prizeRedeemed`
  alert are deleted. Also approved: the form ↔ server validation rules (§ Existing contracts), incl.
  5-digit ZIP hint and the 400-specific Send failed copy. **All screens approved.**
- 2026-10-05 — **Data layer approved:** `endpoints.md` (app consumes list / answers PUT / reward-redemptions
  POST; stops calling legacy redeem, winner-submission, koozie-congrats-seen; `GET …/:id` not consumed)
  and `models.md` (app-side Codable models with `unknown` fallbacks; `KoozieShippingAddress` →
  `ShippingAddress`; giveaway show-once reuses `winnerSheetPresentedAt`; new device-local
  `@Shared(.koozieClaimPromptShown)`). No server changes. Also approved: up-front giveaway sheet fetches
  before presenting (no load-error state); Loading state = reward redemption in flight only.
- 2026-10-05 — **Phase 5 dispositions approved** (Brian: "the rest make sense to me"): table above.
  Changes to the approved deliverables: answers PUT sends non-blank fields only and isn't decoded;
  status-only error mapping (`ClaimAPIError`); koozie prompt marker is per user
  (`koozieClaimPromptShownUserIds`, supersedes the device-wide key above); Home tiles in server order
  with the koozie last (supersedes "newest first"); last-known tiles kept on list failure; no
  swipe-dismiss while Loading / Sending; optional ADDRESS all-or-nothing; Rewards Redeem uses the
  tier's single prize. Release prerequisite added (Show Tix / Meet & Greet `infoFields`). No visual
  change.
- 2026-10-05 — **Phase 7 simplicity gate applied** (§ Simplicity gate): 13 cuts adopted in one wave; the
  two rejected cuts would each reverse an approved decision and are kept as approved. No visual change.
