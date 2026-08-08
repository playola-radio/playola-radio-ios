# iPad Profile screen design (2026-08-06)

Screen 4 of the "Prettify iPad screens" effort (see `LONG_RUNNING.md`). The "Your Profile"
tab renders `ContactPageView` (there is no separate `ProfilePage`). Same **quarantine
pattern** as the earlier screens: a self-contained `ContactPagePadView` branched once on
`horizontalSizeClass == .regular` inside `ContactPageView`; the iPhone/compact path is
byte-for-byte unchanged and the iPad file is disposable.

## Problem

The iPhone profile is a single full-width column of action buttons (Rewards, Notifications,
Contact Us, Ask an Artist, Log out, plus conditional mode-switch buttons). On iPad each button
stretches across the whole width, which reads as a blown-up phone screen.

## Layout (regular size class)

`ContactPagePadView`: a left-aligned title header, then a `ScrollView` whose content is capped
at `maxWidth: 720` and centered:

1. **Profile card** — avatar circle, `model.name`, `model.email`, and the edit-pencil button
   (top-right), wired to `onEditProfileTapped`. Duplicated from the iPhone card styling.
2. **Conditional mode buttons** — "Switch to Listening Mode" (when `isInBroadcastMode`) and
   "Switch to Broadcasting Mode" (when `myStationButtonVisible`), full width, `Color.info`.
   These two `if`s mirror the iPhone view exactly (that page already renders them conditionally).
3. **Action grid** — a 2-col `LazyVGrid` of four `ProfilePadActionButton`s: Rewards,
   Notifications, Contact Us, Ask an Artist. Contact Us keeps its loading spinner
   (`isCheckingSupport`) and unread badge (`@Shared(.unreadSupportCount)`), same as iPhone.
4. **Log out** — full-width outlined button below the grid.

Every button calls the exact same `ContactPageModel` action the compact layout uses.

## Constraints honored

- **Zero business logic in the iPad view.** All labels/flags come from the model; buttons call
  existing model actions. **No model change was needed.**
- **Reuses only the model + duplicated local styling.** `ProfilePadActionButton` is a private,
  local helper (not extracted/shared). The card and special buttons duplicate iPhone styling.
- **iPhone path untouched.** The old body became `compactBody` verbatim; the size-class branch
  and the shared `.background`/`.task`/`.playolaAlert` wrap both. The whole file can be deleted
  without touching iPhone.
- **Control flow:** only the two mode-switch `if`s (matching the iPhone view) plus the leaf-level
  Contact Us spinner/badge conditionals — no new business branching beyond what iPhone already has.

## Verification

App is OAuth-gated, so verified with an `ImageRenderer`→PNG throwaway test. Because `ScrollView`
content blanks under `ImageRenderer`, the header + card + a non-lazy 2-col arrangement of the real
`ProfilePadActionButton` were rendered directly. Composition looked clean and intentional. All 26
`ContactPageTests` pass.
