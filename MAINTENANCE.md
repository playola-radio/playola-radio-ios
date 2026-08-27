# Maintenance

Recurring upkeep tasks for this repo. Ask "What maintenance needs to be done?"
(or run the `whats-due` skill) to see what's due.

**Rules:**
- Dates are ISO (`YYYY-MM-DD`). "Next due" is the date the *next action* should
  happen by — an item is **due** when today ≥ that date.
- When you complete an item, update its "Last completed" and "Next due" dates
  **in the same PR** (same philosophy as `LONG_RUNNING.md`: a stale tracker is
  worse than none).

## Schedule

| Item | Cadence | Last completed | Next due |
|------|---------|----------------|----------|
| [Dependency updates](#dependency-updates) | Monthly | In progress (sweep started 2026-08-27) | 2026-09-03 (finish current sweep) |
| [CI Xcode version check](#ci-xcode-version-check) | Quarterly | Never | 2026-11-27 |
| [Certificates & provisioning check](#certificates--provisioning-check) | Quarterly | Never | 2026-09-10 (first audit) |
| [LONG_RUNNING.md review](#long_runningmd-review) | Monthly | 2026-08-26 | 2026-09-26 |

---

## Dependency updates

Update third-party dependencies once a month. Don't update strictly one
package at a time — update by **group**, one PR per group, so related packages
move together but an unrelated regression is still easy to bisect and revert.

**How updates actually work here (load-bearing):** `Package.resolved` is
**gitignored**, so CI resolves fresh on every build and already floats to the
latest version each `upToNextMajor` range allows. The monthly sweep therefore
means: check upstream for new releases, **raise the `minimumVersion` floors in
`project.pbxproj`** to current, resolve + build + test locally, and catch any
**major** versions (which the ranges block until we opt in).

**Two-refs gotcha:** most packages have TWO `XCRemoteSwiftPackageReference`
entries in `project.pbxproj` (PlayolaRadio + Staging targets). Bump **both** or
the targets drift: Alamofire, GoogleSignIn-iOS, mixpanel-swift,
SDWebImageSwiftUI, SDWebImageSVGCoder, swift-dependencies,
playola-player-swift. (sentry-cocoa, swift-sharing,
swift-identified-collections, swift-custom-dump, SwiftLintPlugins have one.)

### Groups (one PR each)

1. **Point-Free family** — `swift-dependencies`, `swift-sharing`,
   `swift-identified-collections`, `swift-custom-dump`. These are designed to
   move together and share types; updating them independently can cause
   resolution conflicts.
2. **SDWebImage pair** — `SDWebImageSwiftUI`, `SDWebImageSVGCoder`. Same
   ecosystem, shared core.
3. **Sentry** (`sentry-cocoa`) — releases frequently; majors change the SDK
   surface, so read the changelog before a major bump.
4. **Mixpanel** (`mixpanel-swift`)
5. **Alamofire**
6. **GoogleSignIn-iOS** — test the real sign-in flow after updating, not just
   the unit tests.
7. **SwiftLint (plugin + CI, in lockstep)** — two pins that MUST move together
   in the same PR:
   - the `SwiftLintPlugins` exact pin in `project.pbxproj` (build-tool plugin;
     fails the local/CI build on violations), and
   - **`.swiftlint-version`** at the repo root — CI's `swiftlint_check` job
     downloads exactly that SwiftLint release (see `.circleci/config.yml`).

   Use the same version number in both. After bumping, run `make lint` locally:
   new SwiftLint releases add rules that can fail builds nobody touched
   (warnings-as-errors is on). Fix or explicitly disable new rules in
   `.swiftlint.yml` as part of the bump PR.
8. **fastlane** — `bundle update fastlane` (Gemfile/Gemfile.lock only).

### Excluded from routine updates

- **playola-player-swift** — exact-pinned in-house SDK; bumped deliberately
  with feature work, not on a maintenance cadence. (Two-refs gotcha applies.)
- **FRadioPlayer** — vendored local package in `LocalPackages/`; no upstream
  updates.

### Process per PR

- Minor/patch bumps within a group can share one PR. A **major** version bump
  gets its own PR with the changelog reviewed.
- Every PR must build, pass the full test suite, and pass `make lint` before
  merge (same bar as any other PR into `develop`).
- When the sweep finishes, set "Last completed" to that date and "Next due" to
  one month later.

### Current sweep — started 2026-08-27

- [x] Group 1: Point-Free family (swift-dependencies 1.12.0→1.17.0,
      swift-sharing 2.8.0→2.9.1, swift-custom-dump 1.5.0→1.7.1,
      swift-identified-collections already current at 1.1.1)
- [ ] Group 2: SDWebImage pair
- [ ] Group 3: Sentry
- [ ] Group 4: Mixpanel
- [ ] Group 5: Alamofire
- [ ] Group 6: GoogleSignIn-iOS
- [ ] Group 7: SwiftLint (plugin + `.swiftlint-version`)
- [ ] Group 8: fastlane

---

## CI Xcode version check

CircleCI jobs pin a macOS Xcode image (`xcode: 26.2`, five places in
`.circleci/config.yml`). Quarterly:

1. Check what Xcode versions CircleCI offers and what the App Store currently
   requires for submission (Apple periodically raises the minimum SDK).
2. If moving: bump all `xcode:` entries in `.circleci/config.yml` together, and
   keep the local build instruction in sync (we build via
   `DEVELOPER_DIR=/Applications/Xcode-<version>.app` to match CI — see
   memory/docs about local Xcode beta mismatch).
3. A new Xcode = new Swift compiler = possible new warnings, and
   warnings-as-errors is on for App+Staging. Expect to fix warnings in the same
   PR.

---

## Certificates & provisioning check

Signing is fastlane **match**-managed (`fastlane/Matchfile`); staging TestFlight
uses manual + match signing. Apple distribution certificates and provisioning
profiles expire yearly and fail the release lane with confusing errors when
they do. Quarterly:

1. Check expiry dates: `bundle exec fastlane match appstore --readonly` (or
   the Certificates page in the Apple Developer portal).
2. Record the earliest expiry date below, and set this item's "Next due" to at
   least 30 days **before** that date.
3. To renew: use match's normal renew flow. Watch for the known gotcha:
   duplicate distribution certs in the local keychain break the staging build.

**Earliest known expiry:** _not yet audited_

---

## LONG_RUNNING.md review

Monthly, sweep `LONG_RUNNING.md`:

- Is every active task's "Current step" still true?
- Have any soak windows ("Advance when" criteria) been met or breached?
- Are any tasks stale (no movement since last review) — ping the owner or mark
  ⏸️ paused?
- Does every active task have a "Next check" date, and are overdue ones acted
  on?
