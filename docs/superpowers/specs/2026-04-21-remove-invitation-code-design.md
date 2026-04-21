# Remove Invitation Code Gate — Design

Date: 2026-04-21

## Goal

Remove the invitation-code gate and waitlist infrastructure from the iOS app. Simplify the "Invite Your Friends" action to share the App Store URL directly instead of a referral-coded landing page URL.

The app is moving past its invite-only phase, so the entire code-verification, waitlist, and referral-code system becomes dead weight.

## Scope

### Files deleted

- `PlayolaRadio/Views/Pages/InvitationCodePage/InvitationCodePageModel.swift`
- `PlayolaRadio/Views/Pages/InvitationCodePage/InvitationCodePageView.swift`
- `PlayolaRadio/Views/Pages/InvitationCodePage/InvitationCodePageTests.swift`
- `PlayolaRadio/Views/Pages/RewardsPage/ReferralCodeRewardRow.swift`
- `PlayolaRadio/Models/ReferralCode.swift`

### Code removed

**Sheets / navigation:**
- `PlayolaSheet.invitationCode` enum case
- `InvitationCodePageView` case in `SignInPageView`'s `fullScreenCover` switch

**Shared state:**
- `SharedReaderKey.invitationCode` and `SharedReaderKey.hasBeenUnlocked` in `SharedUserDefaults.swift`
- `waitingListEmail` AppStorage key

**SignInPageModel:**
- `@Shared(.hasBeenUnlocked)`, `@Shared(.invitationCode)` declarations
- `_invitationCodesPageModel` instance
- `presentedSheet` property (only used for invitation code)
- `updateSheetPresentation()` method
- `registerInvitationCodeIfPresent()` method and its call sites in both sign-in flows
- Related tests in `SignInPageTests.swift`

**MainContainerModel:**
- `@Shared(.hasBeenUnlocked)` declaration
- Write of `$hasBeenUnlocked.withLock { $0 = true }`
- Related assertions in `MainContainerTests.swift`

**PushNotifications:**
- `@Shared(.hasBeenUnlocked)` gate inside `registerForPushNotifications`
- Related setup in `PushNotificationsTests.swift`

**APIClient:**
- `verifyInvitationCode`, `registerInvitationCode`, `addToWaitingList`, `getOrCreateReferralCode` properties on the client struct
- Live implementations in `APIClient+Live.swift`
- `InvitationCodeError` enum
- Any test mocks / references

**Analytics:**
- `invitationCodeVerified(code:)` event
- `shareWithFriendsTapped` event
- Corresponding entries in the name switch and properties switch in `AnalyticsEvent.swift`

**RewardsPage (Early Bird row removal):**
- `referralCode: ReferralCode?` property
- `referralCodeRequiredHours` constant
- `referralCodeRedemptionStatus` computed var
- `referralCodeRewardLabel`, `referralCodeRewardName`, `referralCodeRequiredHoursLabel`, `referralCodeButtonText`, `referralCodeSharedText` view helpers
- `inviteFriendsTapped()` method
- The Early Bird row rendering in `RewardsPageView.swift`
- Related tests in `RewardsPageTests.swift`

**HomePage:**
- `getOrCreateReferralCode` call in `inviteFriendsButtonTapped` — replaced with plain App Store URL share
- `getOrCreateReferralCode` call in `shareQuestionAiringButtonTapped` — replaced with plain App Store URL share
- `errorCreatingReferralCode` alert if no other callers reference it

### Code changed

**HomePageModel:**
- `inviteFriendsButtonTapped` — share message + `https://apps.apple.com/us/app/playola-radio/id6480465361`, no API call, no error alert
- `shareQuestionAiringButtonTapped` — share airing message + the same App Store URL, no API call

**Xcode project (`PlayolaRadio.xcodeproj/project.pbxproj`):**
- Remove references to deleted files

## Behavior after change

- Sign-in page launches directly into Apple/Google buttons — no invitation/waitlist sheet ever presents
- Push notification registration no longer gates on `hasBeenUnlocked`
- `MainContainer` no longer writes `hasBeenUnlocked`
- Home "Invite Your Friends" tile opens a share sheet with a fixed App Store URL
- Home question-airing share opens a share sheet with the airing message + App Store URL
- Rewards page shows only prize tiers (no Early Bird row)

## Testing

- Remove tests covering the invitation-code/waitlist gate
- Update/add tests in `HomePageTests` confirming invite flows share the App Store URL (no API dependency)
- Update/remove tests in `RewardsPageTests` covering the Early Bird row and `inviteFriendsTapped`
- Update `SignInPageTests` — drop tests that expect the invitation sheet to present
- Update `MainContainerTests` — drop `hasBeenUnlocked` assertions
- Update `PushNotificationsTests` — drop `hasBeenUnlocked` dependency
