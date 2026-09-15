# Pen.dev sessions

When the current app state reports an active Pen.dev Canvas Editor, the task targets a `.pen` file, or the user is actively iterating on a Pen canvas:

- Do not invoke or follow `superpowers:brainstorming`.
- Do not offer its browser-based Visual Companion.
- Use the `pen-dev` skill and the Pen canvas itself for visual exploration, proposals, and iteration.
- Treat direct user feedback on the visible canvas as sufficient approval to continue editing unless a materially different product decision requires clarification.

Outside Pen.dev sessions, normal skill routing still applies.

# Feature design

New features or changes to existing ones start with the shared `design-feature` skill (from the `playola-skills` repo, installed at `~/.claude/skills/design-feature/SKILL.md` and `~/.codex/skills/design-feature/SKILL.md`) BEFORE any implementation code. Its data-layer phases read server models/endpoints from the sibling `../playola` checkout; the iOS canvas file is `design/playola-ios.pen`. Implementation happens in a later session from `design/features/{slug}/implementation-plan.md`.
