# Design assets — how to use this directory

Everything an agent needs to implement a designed screen, and everything a
design session needs to keep this directory trustworthy.

## What's here

| Path | What it is |
|---|---|
| `playola-ios.pen` | The design source of truth — a [pen.dev](https://pen.dev) canvas. Plain JSON; every screen is a top-level frame with a stable node ID. |
| `DESIGN_STATUS.md` | The index: every screen, its node ID, and its implementation status. Start here. |
| `exports/` | 2x PNG renders of every screen, named `<screen-name>--<nodeId>.png`. Top-level dirs mirror status: `current-app/` (shipped), `in-progress/<proposal>/` (Proposed/Implementing), `future/<proposal>/` (Exploring). |
| `images/` | Photos referenced by the .pen file as image fills. Must stay alongside it. |
| `DESIGN_SYSTEM_FIXES.md` | Standalone task brief for reconciling the app's color/font systems. |

## For implementation agents (no pen.dev needed)

You are building a screen from a design. Everything you need is in this
directory — do not look for a design tool.

1. **Find the screen** in `DESIGN_STATUS.md` — get its node ID and status.
   Only implement screens whose proposal you were asked to build.
2. **Look at it**: `Read` the PNG under `exports/in-progress/<proposal>/`
   (agents can view images). This is the visual contract. `current-app/` shows
   what's shipped; `future/` holds explorations no one should build yet.
3. **Get exact values** (colors, spacing, fonts, corner radii) from the .pen
   JSON rather than eyeballing the PNG:

   ```bash
   jq '.. | objects | select(.id? == "tscZI")' design/playola-ios.pen
   ```

   Values like `"$text-primary"` are variables — resolve them in the
   top-level `variables` block of the same file.
4. **Map to the codebase**: designs use raw hex/font values; the app has its
   own tokens — see `.claude/VIEWS.md`. Prefer an existing token that matches
   over a new hex literal.
5. **Never edit `playola-ios.pen`** — it is owned by design sessions. If the
   design is wrong or infeasible, say so in your PR/report instead.
6. **When your screen ships**, update its row in `DESIGN_STATUS.md` in the
   same PR (status → Shipped) and note that the canvas needs its frame moved
   to the CURRENT APP zone (a design session will do the move + re-export).

## For design sessions (pen.dev connected)

The canvas is organized into labeled, color-coded zones — see the "Canvas
layout" section of `DESIGN_STATUS.md`. Conventions:

- New proposal = new labeled row (zone rect + big title + note, 1584px below
  the last row) + a section in `DESIGN_STATUS.md`.
- Zone colors track status: gray = components, amber = exploring,
  blue = proposed or implementing, green = shipped/current app.
- **After any visual change to a screen, re-export it** so `exports/` never
  lies. From the `execute` tool:

  ```js
  Export(["<frameId>"], "png", "./design/exports/<bucket>/<proposal>")
  ```

  then rename the emitted `<nodeId>.png` to `<screen-name>--<nodeId>.png`.
  (Relative paths resolve from the workspace root, not the .pen file's folder.)
- Export dirs follow status: when a proposal's status changes, `git mv` its
  folder between `future/`, `in-progress/`, and (on ship) fold the screens
  into `current-app/`.
- Canvas, `DESIGN_STATUS.md`, and `exports/` change together, in the same
  commit.
