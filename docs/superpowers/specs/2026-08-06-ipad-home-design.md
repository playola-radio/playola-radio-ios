# iPad Home screen design (2026-08-06)

Screen 2 of the "Prettify iPad screens" effort (see `LONG_RUNNING.md`). Same
**quarantine pattern** as Radio Stations: a self-contained `HomePagePadView` branched
once on `horizontalSizeClass == .regular` inside `HomePageView`; the iPhone/compact path
is byte-for-byte unchanged and the iPad file is disposable.

## Layout (regular size class)

Single vertical `ScrollView`, content capped at `maxWidth: 1100`, centered, `.horizontal, 32`
padding:

1. **Header** — `HStack`: the `LogoMark` (96×124, keeps the 10-tap easter-egg gesture) to the
   left of a left-aligned `VStack` with `welcomeMessage` (SpaceGrotesk bold 40) and
   `introMessage` (Inter 18, gray). iPhone stacks these centered; iPad puts them side by side.
2. **Tiles** — 2-col `LazyVGrid` of compact `HomePadTile`s: label (gray) + bold value on the
   left, a red pill button on the right. Driven by the model's existing tile models — the
   conditional feature tiles come from the new `visibleFeatureTileModel`s computed, and the
   always-present listening-time tile is appended separately (it drives a live ticking timer,
   so it stays bound to `listeningTimeTileModel` and forwards `viewAppeared`/`viewDisappeared`).
3. **Stations** — `stationListTitle` + a 2-col `LazyVGrid` of the shared **`StationCardView`**
   leaf (image left, text right), one per `forYouStations` entry, tapping through to
   `stationTapped`.

## Constraints honored

- **Zero business logic in the iPad view.** Which tiles show is decided by
  `HomePageModel.visibleFeatureTileModels` (mirrors the compact layout's order:
  support → scheduled shows → question airing → invite). The view just `ForEach`es.
- **Reuses only shared leaves + the model.** `StationCardView` (shared), the existing tile
  models. `HomePadTile` is a private, duplicated compact style — not extracted/shared.
- **Design drift accepted.** The compact tile styling and the reused iPhone `StationCardView`
  text ordering differ slightly from the mock; the bar is "not embarrassing," and the whole
  file can be deleted without touching iPhone.

## Verification

App is OAuth-gated, so verified with an `ImageRenderer`→PNG throwaway test (ScrollView renders
blank under `ImageRenderer`, so the header + `HomePadTile`s + `StationCardView`s were rendered
in plain non-lazy stacks). Composition matched the target mock. All 41 `HomePageTests` pass.
