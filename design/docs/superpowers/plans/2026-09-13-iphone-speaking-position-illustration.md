# iPhone Speaking Position Illustration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one editable canvas illustration showing the correct speaking position above an upside-down iPhone.

**Architecture:** Build a single clipped top-level frame in `playola-ios.pen` using native frame, shape, text, and icon nodes. Use absolute positioning for the diagram and callouts, then verify resolved bounds and appearance before clearing the placeholder state.

**Tech Stack:** pen.dev `.pen` schema and Pencil `execute` MCP tool.

---

### Task 1: Build and verify the illustration

**Files:**
- Modify: `playola-ios.pen`

- [ ] **Step 1: Find empty canvas space and create a placeholder root frame**

Use `FindEmptySpace({width:720,height:900,padding:120})`, then insert a 720×900 clipped frame named `Instruction · Speak Above iPhone` with `placeholder:true`.

- [ ] **Step 2: Create the instructional diagram**

Insert a concise title, a highlighted imaginary microphone target labeled `TALK HERE`, a dashed vertical distance guide labeled `3–4 inches`, an upside-down iPhone illustration, and a leader identifying `Real iPhone mic` at the phone's upward-facing bottom edge. Give every node a human-readable name.

- [ ] **Step 3: Verify structure and layout**

Use a `Get` visitor to print any `ctx.problems`, confirm no clipped descendants, and keep all text at legible sizes with sufficient contrast.

- [ ] **Step 4: Complete and visually inspect**

Set the root frame's `placeholder:false` and call `TakeScreenshot([rootId])`. Directly update existing nodes if any alignment, clipping, contrast, or hierarchy issue is visible.

- [ ] **Step 5: Re-run final checks**

Use a final `Get` visitor for clipping problems and a final screenshot if fixes were required. Expected: no reported problems and a clear visual hierarchy with `TALK HERE` dominant.
