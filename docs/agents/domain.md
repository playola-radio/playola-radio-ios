# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

**This repo has no domain map of its own.** The authored knowledge map for the whole
product lives in the **server monorepo** at **`../playola/docs/context/`**, and it
already covers iOS: feature docs link directly into this repo's code.

Read, in order:

1. **`../playola/docs/context/README.md`** — the map's entry point and traversal
   procedure.
2. **`../playola/docs/context/features/INDEX.md`** — one doc per capability. Match the
   request to 1–3 feature nodes.
3. For each node, read the **feature doc**, then its linked **surface docs**, then the
   linked backend docs (`ENDPOINTS.md` / `MODEL.md`), and **code entry points LAST**.
   Don't spelunk from the repo root.

The iOS surfaces are catalogued in `../playola/docs/context/surfaces/INDEX.md` as
`ios.schedule` and `ios.player`. Feature docs reference this repo's code through
`repo://ios/...` links — e.g. `repo://ios/PlayolaRadio/Views/Pages/BroadcastPage` in
`features/airings.md`, and `repo://ios/PlayolaRadio/Views/Pages/SeriesListPage` in
`features/shows.md` and `features/episodes.md`.

A `repo://ios/<path>` link resolves to `<ios-root>/<path>`, where `<ios-root>` comes
from `../playola/docs/context/repos.yaml` — `rootHint: ~/playola/playola-radio-ios`,
overridable with the `PLAYOLA_IOS_ROOT` environment variable. So
`repo://ios/PlayolaRadio/Views/Pages/PlayerPage` is this repo's
`PlayolaRadio/Views/Pages/PlayerPage`.

**If the monorepo isn't checked out** at `../playola`, ask for its path (the same
convention as the "Server / API Documentation" section of `CLAUDE.md`). Don't guess at
domain semantics from iOS code alone, and don't start a second map here.

This repo has **no `CONTEXT.md`, no `CONTEXT-MAP.md`, and no `docs/adr/`**. Don't look
for them, and don't treat their absence as a gap to fill. If the `/domain-modeling`
skill would create one, prefer extending `../playola/docs/context/` instead, so the
product keeps one map rather than two.

## What lives here instead

This repo's own docs are implementation guidance, not domain modeling — consult them
for *how* to write code here, after the map has told you *what* to build:

| Topic | File |
| --- | --- |
| Creating a new page | `.claude/PAGE_CREATION.md` |
| Implementing a designed screen | `design/README.md`, `design/DESIGN_STATUS.md` |
| API calls from iOS | `.claude/API_CLIENT.md` |
| Navigation | `.claude/NAVIGATION.md` |
| Testing | `.claude/TESTING.md` |
| View styling | `.claude/VIEWS.md` |
| Multi-PR efforts / soaks | `LONG_RUNNING.md` |

## Use the map's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a
hypothesis, a test name), use the term as defined in the relevant
`../playola/docs/context/features/<id>.md`. `Show`, `Episode`, and `Airing` mean the
same thing here and on the server — don't drift to iOS-local synonyms.

If the concept you need isn't in the map yet, that's a signal: either you're inventing
language the project doesn't use (reconsider) or there's a real gap (note it, and
extend the relevant feature doc in the monorepo).

## Flag conflicts with the map

If your output contradicts a documented decision in `../playola/docs/context/`, surface
it explicitly rather than silently overriding:

> _Contradicts `docs/context/features/airings.md` (airings are immutable once aired),
> but worth reopening because…_

Note that `../playola/scripts/check-context-links.py` validates `repo://ios/...` links
in CI. If you move or rename a file the map points at, update the monorepo's map in the
same effort or its `context-links` job breaks.
