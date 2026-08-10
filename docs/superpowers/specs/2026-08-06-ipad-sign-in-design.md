# iPad Sign In screen design (2026-08-06)

Screen 3 of the "Prettify iPad screens" effort (see `LONG_RUNNING.md`). Same
**quarantine pattern** as the earlier screens: a self-contained `SignInPadView` branched
once on `horizontalSizeClass == .regular` inside `SignInPage`; the iPhone/compact path is
byte-for-byte unchanged and the iPad file is disposable.

## Problem

The iPhone sign-in is a single full-width centered column. On iPad it stretches to the full
width — the Google / Apple buttons span ~960pt and the subtitle line runs edge to edge, which
reads as a blown-up phone screen rather than an intentional layout.

## Layout (regular size class)

`SignInPadView` reuses the same gradient background, then centers a fixed-width (460pt) **auth
card** on it:

- **Logo** — `LogoMark` (96pt tall) over the `PlayolaWordLogo` (220pt wide).
- **Welcome** — `welcomeTitle` (system 32 bold) + `welcomeSubtitle` (system 17, 70% white).
- **Auth buttons** — the shared `CustomGoogleSignInButton` and the system
  `SignInWithAppleButton`, both wired to the exact same `SignInPageModel` actions the compact
  layout calls (`signInWithGoogleButtonTapped`, `signInWithAppleButtonTapped(request:)`,
  `signInWithAppleCompleted(result:)`).
- **Footer** — the terms-of-service / privacy-policy line, unchanged text from the model.

The card has a faint translucent fill (`Color.white.opacity(0.05)`), 24pt corner radius, and a
hairline white stroke so it reads as a deliberate panel.

## Constraints honored

- **Zero business logic in the iPad view.** All text comes from the model; both buttons call
  existing model actions. No model change was needed.
- **Reuses only shared leaves + the model.** `CustomGoogleSignInButton` (shared, defined in
  `SignInPageView.swift`) and the system Apple button. The card styling is duplicated locally,
  not extracted.
- **iPhone path untouched.** The old body became `compactBody` verbatim; the size-class branch
  and the shared `.playolaAlert` wrap both. The whole `SignInPadView` file can be deleted
  without touching iPhone.

## Verification

App is OAuth-gated, so verified with an `ImageRenderer`→PNG throwaway test. The card, logo,
text, and Google button render correctly; the system `SignInWithAppleButton` shows a placeholder
under `ImageRenderer` (it's a UIKit-backed control that `ImageRenderer` can't materialize) — it
renders normally in the real app, identical to the iPhone path. All 23 `SignInPageTests` pass.
