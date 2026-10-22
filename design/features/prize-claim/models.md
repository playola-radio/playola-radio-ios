# Prize Claim — Model changes

**No server model, column, index, constraint, or enum changes.** The backend tables this feature reads
and writes (`fulfillmentRequests`, `userPrizes`, `prizes.infoFields`) already exist on playola `develop`
(`283fbe2b`) and live in production since 2026-10-04. This file records the
**app-side** models: new Codable types decoding the server contract, the app types they replace, and one
new piece of device-local state. Every server enum decodes with an `unknown` fallback (repo rule: a
surprise server value must never crash decoding or silently hide UI).

| Change | Model | File | Summary |
|---|---|---|---|
| New | `FulfillmentRequest` | `Models/FulfillmentRequest.swift` | Decodes `FulfillmentRequestSummary` |
| New | `InfoField` | `Models/FulfillmentRequest.swift` | One form field definition |
| New | `InfoAnswer` | `Models/FulfillmentRequest.swift` | One stored/submitted answer: text or address |
| Changed | `KoozieShippingAddress` → `ShippingAddress` | `Models/ShippingAddress.swift` | Renamed + made `Codable`; used by every ADDRESS field |
| New | `SubmitFulfillmentAnswersRequest` | `Models/FulfillmentRequest.swift` | `PUT …/answers` body |
| New | `CreateRewardRedemptionRequest` | `Models/FulfillmentRequest.swift` | `POST …/reward-redemptions` body |
| New | `ClaimAPIError` | `Core/API/` | Status-code mapping for the three claim calls |
| Removed | `RedeemKooziePrizeRequest` | `Models/KoozieShippingAddress.swift` | Legacy koozie redeem body |
| Removed | `GiveawayWinnerSubmissionRequest` | `Models/GiveawayWinnerSubmissionRequest.swift` | Legacy winner-submission body |
| Changed | `RewardsProfile` | `Models/RewardsProfile.swift` | Stop reading `shouldShowKoozieCongrats` |
| New | `@Shared(.koozieClaimPromptShownUserIds)` | `State/` | Per-account show-once marker for the up-front koozie sheet |
| Unchanged | `GiveawayParticipation.winnerSheetPresentedAt` | `Models/GiveawayParticipation.swift` | Becomes the show-once marker for giveaway wins |

## FulfillmentRequest — New

`struct FulfillmentRequest: Decodable, Equatable, Identifiable, Sendable`

| Property | Type | JSON | Notes |
|---|---|---|---|
| `id` | `String` | `id` | PUT path; Home tile identity (`ForEach` key) |
| `status` | `Status` | `status` | Only `.awaitingInfo` makes a Home tile |
| `source` | `Source` | `source` | Tile label: `.reward` → "You earned", else "You won" |
| `giveawayEventId` | `String?` | `giveawayEventId` | Matches a `GiveawayParticipation.id` for the up-front win sheet |
| `prizeTitle` | `String?` | `prize.title` | Sheet title + tile content; nil → "Your prize" (copy lives in the model) |
| `prizeImageUrl` | `URL?` | `prize.imageUrl` | nil → collapsed header (approved) |
| `infoFields` | `[InfoField]` | `infoFields` | Form definition, in server order |
| `infoAnswers` | `[String: InfoAnswer]` | `infoAnswers` | Pre-fills the form; undecodable values are dropped, not fatal |

- **Enums:** `Status` = `awaitingInfo` (`awaiting_info`), `readyToShip` (`ready_to_ship`), `unknown` —
  the list endpoint returns only those two, so `fulfilled` / `canceled` are not modeled. `Source` = `giveaway`, `reward`, `unknown`.
- **Not decoded:** `userPrizeId` and `prize.number` (nothing reads them).
- **Source of truth:** the server. The app never persists requests — Home holds the last successful list
  in memory (kept when a refetch fails) and refetches on Home appear / foreground and after every PUT /
  POST outcome. The PUT response is not decoded (admin callers get a different shape — endpoints.md).

## InfoField — New

| Property | Type | Notes |
|---|---|---|
| `key` | `String` | Answer key |
| `label` | `String` | Field label as shown |
| `type` | `FieldType` | `shortText`, `multiLineText`, `singleChoice`, `address`, `unknown` |
| `options` | `[String]` | SINGLE_CHOICE options (absent → `[]`); drives chips / inline list / picker |
| `required` | `Bool` | Gates Send; drives the Incomplete hint and the picker's "None" row |

- **`unknown` type:** best effort — rendered as a SHORT_TEXT field and the server stays the validator; if
  it rejects the value, the user sees Send failed (400 copy). Adding a field type is a coordinated
  server + app change, so this is a safety net, not a supported path.

## InfoAnswer — New

`enum InfoAnswer: Codable, Equatable, Sendable { case text(String); case address(ShippingAddress) }`
— decodes a JSON string as `.text`, an object as `.address`; encodes back to the same JSON. SINGLE_CHOICE
answers are `.text` holding the exact option string.

## ShippingAddress — Changed (was `KoozieShippingAddress`)

| Property | Type | Change | Notes |
|---|---|---|---|
| (type) | `Encodable` → `Codable` | Changed | Now also decoded from `infoAnswers` to pre-fill |
| `country` | — | unchanged (absent) | Never sent; ignored on decode (server defaults "US") |

Other properties (`fullName`, `addressLine1`, `addressLine2?`, `city`, `state`, `postalCode`) are
unchanged. `KoozieAddressFormModel` is generalized into the claim sheet's address-field model; its
existing trim + ZIP regex (`^\d{5}(-\d{4})?$`, so a pre-filled ZIP+4 stays valid) + `canSubmit` logic is
kept, tightened to the spec.md validation rules (State from the server's 59 codes; the number pad types
5 digits). An optional address is valid when wholly blank (omitted) or complete.

## ClaimAPIError — New

`enum ClaimAPIError: Error, Equatable { case invalidAnswers, notOpen, conflict, failed }` with one
`init(status: Int?)` mapping (400 → `invalidAnswers`; 403 / 404 → `notOpen`; 409 → `conflict`; anything
else, including a transport failure, → `failed`) — thrown by the three new `APIClient` closures. The
caller interprets `conflict`: on the answers PUT it is No longer open; on the reward-redemption POST it
means already claimed. The server's error body carries only a message, so nothing is parsed from it.

## SubmitFulfillmentAnswersRequest / CreateRewardRedemptionRequest — New

- `SubmitFulfillmentAnswersRequest { infoAnswers: [String: InfoAnswer] }` — only fields with a value;
  never `.text("")` (see endpoints.md).
- `CreateRewardRedemptionRequest { prizeId: String }` — no `stationId`.

## RewardsProfile — Changed

| Property | Change | Notes |
|---|---|---|
| `shouldShowKoozieCongrats` | Removed | Congrats card dropped; the server keeps the field for old builds |

`koozieEarned` is kept: it means "a koozie `UserPrize` exists", so it flips true right after the
reward-redemption POST (server `koozie.lib.ts`) and is the "Claimed" signal for the Listening tile and
the unclaimed-koozie Home tile.

## @Shared(.koozieClaimPromptShownUserIds) — New

| Key | Storage | Type | Default |
|---|---|---|---|
| `koozieClaimPromptShownUserIds` | `.fileStorage` | `Set<String>` (user ids) | `[]` |

- **Reads:** `HomePageModel` up-front koozie presentation (Home appear and foreground; present only when the signed-in user's id
  is absent, the koozie is earned by hours, and `koozieEarned != true`). **Writes:** inserts the user id
  when that sheet is presented. Not cleared on sign-out, so a second account on the same device gets its
  own prompt and re-signing-in doesn't re-prompt. (The koozie is one prize per user, so user id is the
  prize identity.)
- **Source of truth:** device-local by design — the server has no "prompt shown" state before a
  `UserPrize` exists, and a reinstall re-showing it once is harmless. The Home tile is the durable
  re-entry.

## GiveawayParticipation — Unchanged (role changes)

`winnerSheetPresentedAt` already exists and is already persisted. The up-front giveaway sheet now gates
on `winnerSheetPresentedAt == nil` (show once) instead of today's `!submissionCompleted` (re-present
every foreground). No new giveaway storage. Upgrade behavior: a win whose sheet an older build already
showed gets the Home tile only, no new prompt. `submissionCompleted` no longer gates anything — the
fulfillment request's status is the authority on what's outstanding (a legacy email submission does not
make a request ready).
