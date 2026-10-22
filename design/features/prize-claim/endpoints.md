# Prize Claim — Endpoint changes

**No server endpoint is added, changed, or removed.** Every endpoint below is live in production (the
fulfillment migrations ran 2026-10-04) and on playola `develop` (rechecked at `283fbe2b`). This file
records the **app's** consumption changes: which endpoints the app starts calling, which it stops
calling, and how it handles each response. Server contracts are owned by
`server/src/api/fulfillmentRequests/ENDPOINTS.md` and `server/src/api/rewardRedemptions/ENDPOINTS.md`;
shapes below are the subset the app relies on.

**Errors, all calls:** the server's error body is `{ "error": { "message": "…" } }` — symbolic names
like `PRIZE_ALREADY_REDEEMED` are not on the wire, so the app branches on **HTTP status only**. The new
`APIClient` closures map statuses to `ClaimAPIError` (models.md). A 401 is handled like every other
authenticated call in the app today (no app-wide re-auth exists): it surfaces as the generic failure
path below.

| Change (app) | Method | Path | Auth | Purpose |
|---|---|---|---|---|
| New consumer | GET | `/v1/users/me/fulfillment-requests` | JWT, self | Home prize tiles; locate a giveaway win's request |
| New consumer | PUT | `/v1/fulfillment-requests/:id/answers` | JWT, recipient | Claim sheet "Send it to me" |
| New consumer | POST | `/v1/users/me/reward-redemptions` | JWT, self | Claim sheet "Claim it" (koozie + Rewards tiers) |
| Not consumed | GET | `/v1/fulfillment-requests/:id` | JWT, recipient | — every entry point already holds the full summary |
| Removed consumer | POST | `/v1/rewards/users/me/prizes/:prizeId/redeem` | JWT, self | Replaced by reward-redemptions + answers |
| Removed consumer | POST | `/v1/giveaway-events/:eventId/winner-submission` | JWT, winner | Replaced by answers |
| Removed consumer | POST | `/v1/rewards/users/me/koozie-congrats-seen` | JWT, self | Congrats card dropped |

Removed consumers stay live on the server for app builds in the wild; nothing here asks the server to
delete them.

## GET /v1/users/me/fulfillment-requests
- **Change:** New consumer (`APIClient.getMyFulfillmentRequests`)
- **Auth:** JWT; `me` alias (`isOperatingOnSelf`)
- **Path params:** none
- **Query params:** none
- **Request body:** none
- **Response `200`:** `awaiting_info` + `ready_to_ship` requests only, server-ordered (`createdAt DESC`;
  the timestamp itself is not serialized)
  ```json
  [
    {
      "id": "4b1c2f0e-7a51-4c1e-9d3e-2f6a8b0c1d11",
      "status": "awaiting_info",
      "source": "giveaway",
      "giveawayEventId": "9e8d7c6b-5a49-4382-a1b0-c9d8e7f6a5b4",
      "userPrizeId": null,
      "prize": { "title": "Tour Poster", "number": 12, "imageUrl": null },
      "infoFields": [
        { "key": "shirtSize", "label": "Shirt size", "type": "SINGLE_CHOICE", "options": ["S", "M", "L", "XL"], "required": true },
        { "key": "shippingAddress", "label": "Shipping address", "type": "ADDRESS", "required": true }
      ],
      "infoAnswers": {}
    }
  ]
  ```
- **Errors:**

  | Status | When | App handling |
  |---|---|---|
  | any failure (401, network, 5xx) | — | Home keeps its last-known prize tiles (in-memory) and retries on the next Home appear / foreground; the up-front giveaway sheet is not presented this time |

- **App rules:**
  - Home renders one prize tile per item with `status == awaiting_info`, in server order, then the
    unclaimed-koozie tile last. `ready_to_ship` items make no tile.
  - Giveaway win: the request is the item whose `giveawayEventId` equals the participation id
    (`GiveawayParticipation.id` is the event id). The app fetches first and presents only once a match
    is found: `awaiting_info` → the form; `ready_to_ship` → Nothing to fill in. No match → no sheet yet;
    retried on the next foreground (the Home tile covers it either way). The server's status is the
    authority on what's outstanding; `GiveawayParticipation.status` only drives local presentation.
- **Consumers:** Home (prize tiles), up-front giveaway-win presentation (`MainContainerModel`)

## PUT /v1/fulfillment-requests/:id/answers
- **Change:** New consumer (`APIClient.submitFulfillmentAnswers`)
- **Auth:** JWT; recipient (checked in the server lib)
- **Path params:** `id` — fulfillment request id
- **Request body:** only fields that have a value — never `""`, so a submit can't clear an answer
  another device or an operator already saved. Free text is trimmed; a SINGLE_CHOICE value is the exact
  option string (not trimmed); an ADDRESS is the full object, never partial (an optional address is
  either omitted or complete). `country` and `notes` are never sent.
  ```json
  {
    "infoAnswers": {
      "shirtSize": "M",
      "shippingAddress": {
        "fullName": "Jane Doe",
        "addressLine1": "123 Main St",
        "addressLine2": null,
        "city": "Austin",
        "state": "TX",
        "postalCode": "78701"
      }
    }
  }
  ```
- **Response `200`:** not decoded. A recipient gets the summary but an **admin** caller gets the operator
  `FulfillmentQueueRow` shape, so the app treats any 2xx as success and refetches the list.
- **Errors:**

  | Status | When | App handling |
  |---|---|---|
  | 400 | unknown key, wrong type, invalid address, oversized text | Send failed, 400 copy ("Some of your answers didn't go through…"); answers kept; `reportIssue` (client validation should have caught it) |
  | 403 | caller no longer the recipient (winner reassigned) | No longer open; list refetched so the tile disappears |
  | 404 | request gone | No longer open; list refetched |
  | 409 | request fulfilled / canceled / unassigned, or the patch would un-ready a `ready_to_ship` request | No longer open; list refetched |
  | 401, network, 5xx | — | Send failed, connection copy; answers kept |

- **App rules:** 2xx → Sent, then the Home tile list is refetched. Client-side validation (spec.md
  § Form ↔ server validation check) gates the Send button, so a 400 is a bug, not a user path. The
  sheet can't be swiped away while the PUT is in flight. Two devices submitting the same request is
  last-write-wins (accepted, spec.md § Adversarial review).
- **Consumers:** Claim sheet (Sending → Sent / Send failed / No longer open)

## POST /v1/users/me/reward-redemptions
- **Change:** New consumer (`APIClient.createRewardRedemption`)
- **Auth:** JWT; `me` alias (`isOperatingOnSelf`)
- **Request body:** `prizeId` is the tier's single prize (every production tier has exactly one; a tier
  with none hides Redeem). `stationId` is never sent (no production tier is per-station).
  ```json
  { "prizeId": "3f2a1b0c-9d8e-4f7a-b6c5-d4e3f2a1b0c9" }
  ```
- **Response `201`:** a summary, `"source": "reward"`, `giveawayEventId: null`, `userPrizeId` set;
  `status` is `awaiting_info`, or `ready_to_ship` when the prize has no required fields.
  ```json
  {
    "id": "c7d6e5f4-a3b2-4c1d-8e9f-0a1b2c3d4e5f",
    "status": "awaiting_info",
    "source": "reward",
    "giveawayEventId": null,
    "userPrizeId": "0f1e2d3c-4b5a-4968-8776-655443322110",
    "prize": { "title": "Playola Koozie", "number": null, "imageUrl": null },
    "infoFields": [
      { "key": "shippingAddress", "label": "Shipping address", "type": "ADDRESS", "required": true }
    ],
    "infoAnswers": {}
  }
  ```
- **Errors:**

  | Status | When | App handling |
  |---|---|---|
  | 409 | already redeemed (double tap, other device, lost 201 then retry) | counts as claimed: report the claim to the caller (koozie / Rewards tier marked claimed), dismiss, refetch the list — a tile appears only if something is still to fill in |
  | 403 / 404 | wrong user, unknown prize | No longer open; `reportIssue` |
  | 400 | malformed prize id | Send failed, connection copy; `reportIssue` (the user can't fix a prize id) |
  | 401, network, 5xx | — | Send failed, connection copy; "Try again" re-posts |

- **App rules:** 201 → the same sheet moves to the form (or Nothing to fill in when `ready_to_ship`), and
  the claim is reported to whoever opened the sheet: the Rewards page marks that tier redeemed; the
  koozie keeps a local "claimed" override until a refreshed rewards profile shows `koozieEarned`. The
  sheet can't be swiped away while the POST is in flight. Server side effect: the `UserPrize` is created
  `contacted`, so no legacy congrats/address email is sent.
- **Consumers:** Claim sheet (Reward · Not Yet Claimed → Loading → form), reached from the koozie
  threshold, the unclaimed-koozie Home tile, and Rewards page "Redeem"

## GET /v1/fulfillment-requests/:id
- **Change:** Not consumed in v1
- **Why:** every Claim sheet entry point already holds a full summary (list item or POST response). A
  summary that went stale while the sheet was open is caught by the PUT (403 / 404 / 409 → No longer
  open). Adopt it only if a future entry point (e.g. a push deep link by request id) carries just an id.
- **Consumers:** none

## POST /v1/rewards/users/me/prizes/:prizeId/redeem
- **Change:** Removed consumer (`APIClient.redeemPrize`, `APIClient.redeemKooziePrize`)
- **Replacement:** `POST /v1/users/me/reward-redemptions`, then `PUT /v1/fulfillment-requests/:id/answers`
- **Still called by:** app builds before this release (server keeps it; it still sends the legacy email)
- **Consumers:** none after this change (was `RedeemPrizeSheetModel`, `KoozieTileModel`)

## POST /v1/giveaway-events/:eventId/winner-submission
- **Change:** Removed consumer (`APIClient.submitGiveawayWinnerDetails`)
- **Replacement:** `PUT /v1/fulfillment-requests/:id/answers`
- **Still called by:** app builds before this release
- **Consumers:** none after this change (was `GiveawayWinnerSheetModel`)

## POST /v1/rewards/users/me/koozie-congrats-seen
- **Change:** Removed consumer (`APIClient.markKoozieCongratsSeen`)
- **Replacement:** none — the congrats card is dropped (approvals log 2026-10-05); the Claim sheet's
  Sent state is the congrats moment. The app also stops reading `RewardsProfile.shouldShowKoozieCongrats`.
- **Still called by:** app builds before this release
- **Consumers:** none after this change (was `KoozieTileModel`)
