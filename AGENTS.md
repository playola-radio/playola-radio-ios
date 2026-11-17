# Pen.dev sessions

When the current app state reports an active Pen.dev Canvas Editor, the task targets a `.pen` file, or the user is actively iterating on a Pen canvas:

- Do not invoke or follow `superpowers:brainstorming`.
- Do not offer its browser-based Visual Companion.
- Use the `pen-dev` skill and the Pen canvas itself for visual exploration, proposals, and iteration.
- Treat direct user feedback on the visible canvas as sufficient approval to continue editing unless a materially different product decision requires clarification.

Outside Pen.dev sessions, normal skill routing still applies.

# Feature design

New features or changes to existing ones start with the shared `design-feature` skill (from the `playola-skills` repo, installed at `~/.claude/skills/design-feature/SKILL.md` and `~/.codex/skills/design-feature/SKILL.md`) BEFORE any implementation code. Its data-layer phases read server models/endpoints from the sibling `../playola` checkout; the iOS canvas file is `design/playola-ios.pen`. Implementation happens in a later session from `design/features/{slug}/implementation-plan.md`.

# Release notes (changelog.d/)

**Never edit `CHANGELOG.md` in a pull request.** A PR with a user-facing change
adds one new file, `changelog.d/<short-kebab-description>.md`, holding a
`### Changes` heading and plain-English `- ` bullets (format and strict rules
in `changelog.d/README.md`; check with `make changelog-check`). Pure chores add
no file and say so in the PR's Changelog section. `scripts/release.sh` collects
the files into `CHANGELOG.md` at release time.

# UX evidence

- The tool lives in `playola-radio/ai-skills`; clone it to `~/playola/playola-skills` (or set `UX_EVIDENCE_HOME` to its `ux-evidence/tool` folder). First time on a machine: `make ux-evidence-setup`, then sign in to the Staging app in a simulator and run `make ux-evidence-ios-login` (add `DEVICE=<udid>` when more than one booted simulator has it).
- If the branch changes anything under `PlayolaRadio/` or `PlayolaRadio.xcodeproj/`, then before the PR is opened either `make ux-evidence-verify` passes or the PR body contains `UX evidence: none — <reason>`.
- The agent that implemented the change writes the case under `qa/ux/` and runs `make ux-evidence CASE=<case-id>`. Create it with `make ux-evidence-new CASE=<case-id> CLASSIFICATION=<visual|functional> BEFORE=<required|not-applicable>` (visual = screenshots, functional = a video of `flow.yaml` only), then edit `setup.yaml` and `flow.yaml`; `qa/ux/example-stations/` and `qa/ux/example-navigation/` are examples. Never show the profile tab or account details in a flow.
- Right after the PR is created, run `make ux-evidence-publish PR=<number>`. After any later push, run `make ux-evidence-verify`; if stale, re-record and publish again. Both steps apply only when the branch has evidence cases; a PR using `UX evidence: none — <reason>` skips both.
- A failed "before" run is a failure to fix, never a reason to switch to `not-applicable`.
- See `qa/ux/README.md`.
