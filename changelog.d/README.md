# changelog.d

Release notes wait here until the next release. A pull request with a change
people will notice adds **one new file** to this folder instead of editing
`CHANGELOG.md`, so pull requests never conflict over release notes.

When a release is cut, `scripts/release.sh` runs `scripts/changelog.py roll`,
which moves every note into a dated version section of `CHANGELOG.md` and
deletes the files it collected. This README is never collected or deleted.

## File name

`changelog.d/<short-kebab-description>.md`, for example
`changelog.d/resume-last-station.md`. Any unique name works; notes are collected
in file-name order.

## Format

```markdown
### Changes

- Tapping play on the lock screen now resumes the last station you listened to.
```

The check is strict. Anything else fails it, and a failing note blocks the
release until it's fixed:

- A `### Changes` heading, then one or more `- ` bullets under it.
- One line per bullet: no wrapped lines and no nested bullets.
- Blank lines and one-line `<!-- ... -->` comments are fine.

Write each bullet in plain English: what a listener or station owner can now do,
or what got fixed. Leave out class names, ticket numbers, and implementation
details.

## Which pull requests need one

Anything a user can see or feel: new features, changed behavior, and bug
fixes. Pure chores need no file (refactors, tests, CI, tooling, docs, or
dependency bumps with no visible effect). Say so in the pull request's
Changelog section instead.

## Check your note

```sh
make changelog-check
```

This prints every pending note, or names the `file:line` that's wrong. CI runs
the same check on every pull request.
