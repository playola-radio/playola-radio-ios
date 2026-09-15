# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Provisioning

GitHub requires a label to exist before `gh issue edit --add-label` can attach it;
applying a missing label fails and leaves the issue unlabeled. Of the five above, only
**`wontfix`** currently exists in `playola-radio/playola-radio-ios`.

Create the four missing labels once, before the first triage run:

```bash
gh label create needs-triage    --repo playola-radio/playola-radio-ios --color FBCA04 --description "Maintainer needs to evaluate this issue"
gh label create needs-info      --repo playola-radio/playola-radio-ios --color D4C5F9 --description "Waiting on reporter for more information"
gh label create ready-for-agent --repo playola-radio/playola-radio-ios --color 0E8A16 --description "Fully specified, ready for an AFK agent"
gh label create ready-for-human --repo playola-radio/playola-radio-ios --color 1D76DB --description "Requires human implementation"
```

`gh label create` fails if the label already exists; add `--force` to make the command
idempotent, or check first with `gh label list`.

Labels are per-repo: creating them in the monorepo does **not** create them here.

Before applying any label from this table, verify it exists:

```bash
gh label list --repo playola-radio/playola-radio-ios --limit 100 --json name --jq '.[].name' | grep -qx "<label>"
```
