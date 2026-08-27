---
name: whats-due
description: Use when the user asks what maintenance needs to be done, what long-running tasks need attention, what's due/overdue, or invokes /whats-due. Reads MAINTENANCE.md and LONG_RUNNING.md and reports items whose due date has arrived.
---

# What's Due

Report which maintenance items and long-running tasks are due, from the two
trackers at the repo root.

## Steps

1. Get today's date (from context, or `date +%F`).
2. Read `MAINTENANCE.md`. In the **Schedule** table, compare each row's
   "Next due" (ISO `YYYY-MM-DD`) to today. Also check the "Current sweep"
   checklist under Dependency updates for unchecked groups.
3. Read `LONG_RUNNING.md`. In the **Active** table, compare each row's
   "Next check" date to today. `—` means opportunistic — skip it.
4. Report three buckets, most urgent first:
   - **Overdue** (due date < today) — include how many days overdue.
   - **Due today / this week** (within 7 days).
   - **Coming up** (within 30 days) — one line each, no detail.
5. For each due item, say what the *next concrete action* is (pull it from the
   item's section in the file — e.g. which dependency group is next, or which
   soak gate to verify), not just that it's due.
6. If nothing is due, say so and state the nearest upcoming date.

## Rules

- Dates in both files are ISO (`YYYY-MM-DD`); an item is due when
  today ≥ the date.
- Do NOT start doing the work — this skill only reports. Offer to tackle a
  specific item as a follow-up.
- If you *do* subsequently complete an item, update its dates in the tracker
  in the same PR as the work (both files require this).
