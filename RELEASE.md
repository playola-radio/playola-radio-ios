# Releasing Playola Radio iOS

This document describes how releases ship today and the target flow once
TestFlight upload is automated on CircleCI.

App Store promotion (TestFlight to public App Store) is intentionally manual
in both flows.

## Current release flow

1. **Create the release PR.** On a clean `develop`, run:

   ```sh
   ./scripts/release.sh
   ```

   The script creates `release/X.Y.Z`, bumps `MARKETING_VERSION` in
   `PlayolaRadio.xcodeproj/project.pbxproj`, runs `agvtool` to bump the build
   number, lists the PRs merged since the last release, and opens a release
   PR targeting `main`.

2. **Merge the release PR using "Create a merge commit".** Do NOT squash.

   `scripts/release.sh` computes the "unreleased PRs" list by walking the
   merge history of `develop` since the last sync-back from `main`. Squashing
   the release PR collapses the merge commits on `main` into a single commit
   that no longer shares SHAs with `develop`'s history. The next run of
   `release.sh` then re-lists PRs that have already shipped. Using "Create a
   merge commit" preserves the first-parent chain and keeps the PR list
   accurate.

3. **Auto-tag fires.** `.github/workflows/auto-tag-release.yml` runs on push
   to `main`, reads `MARKETING_VERSION` from the pbxproj, and pushes tag
   `vX.Y.Z` if it does not already exist.

4. **Sync-back PR opens.** `.github/workflows/sync-main-to-develop.yml` fires
   on the same push and opens a PR merging `main` back into `develop`. Merge
   it promptly so the next release diff is accurate.

5. **Build and upload from the developer laptop.** On the machine that holds
   the production signing auth and secrets:

   ```sh
   git checkout main && git pull
   bundle exec fastlane release_production
   ```

   The lane runs `ensure_git_status_clean`, `ensure_git_branch('main')`,
   `scan`, `build_app`, `upload_to_testflight` (falling back to local Apple
   auth), and `sentry_debug_files_upload`.

6. **Promote manually.** Once the TestFlight build finishes processing,
   promote it to the App Store from App Store Connect when ready.

## Target release flow (after PRs 2 through 5 land)

Steps 1 through 4 above are unchanged. Steps 5 and 6 become:

5. **CircleCI builds and uploads on tag push.** Pushing `vX.Y.Z` triggers a
   `release_build` job that decodes secrets from env vars, runs `match`
   readonly, runs `scan`, runs `build_app`, uploads to TestFlight with the
   App Store Connect API key, and uploads dSYMs to Sentry. No developer
   laptop is involved.

6. **Promote manually.** Unchanged.

The incremental rollout is:

- PR 2: make the `release_production` Fastlane lane CI-runnable.
- PR 3: add `scripts/encode-secrets.sh` and `scripts/ci-write-secrets.sh`.
- PR 4: add a tag-filtered CircleCI job that builds but does not upload.
- PR 5: enable `upload_to_testflight` and `sentry_debug_files_upload`.

## Hotfix path

For a build-number-only bump on an existing version (for example, to
re-upload after a TestFlight processing failure), run:

```sh
./scripts/bump-build.sh          # local commit only
./scripts/bump-build.sh --push   # commit and push
```

This bumps the build number via `agvtool`, commits the change, and
optionally pushes. Use this on a branch that will still go through the
normal release-PR flow. It does not create a PR or tag by itself.

## Secrets

Once automation is in place, the following env vars must be set in a
CircleCI context (suggested name `ios-release`) and attached to the
release workflow. Names only; values live in CircleCI.

| Variable | Purpose |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | ASC API key identifier. |
| `APP_STORE_CONNECT_API_ISSUER_ID` | ASC issuer UUID. |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Contents of the `.p8` private key used by fastlane to authenticate to App Store Connect. |
| `MATCH_PASSWORD` | Passphrase that decrypts the fastlane-match certificate repo. |
| `MATCH_GIT_PRIVATE_KEY` | SSH key with read access to the `fastlane-match-certs-and-profiles` repo. |
| `SECRETS_XCCONFIG_B64` | Base64 of `PlayolaRadio/Config/Secrets.xcconfig`. |
| `SECRETS_LOCAL_XCCONFIG_B64` | Base64 of `PlayolaRadio/Config/Secrets-Local.xcconfig`. |
| `SECRETS_DEVELOPMENT_XCCONFIG_B64` | Base64 of `PlayolaRadio/Config/Secrets-Development.xcconfig`. |
| `SECRETS_STAGING_XCCONFIG_B64` | Base64 of `PlayolaRadio/Config/Secrets-Staging.xcconfig`. |
| `SENTRY_AUTH_TOKEN` | Auth token used by `sentry_debug_files_upload` to push dSYMs. |

## Rotating or adding a secret

PR 3 will add `scripts/encode-secrets.sh` and `scripts/ci-write-secrets.sh`
to automate the encode/decode of the xcconfig secrets. Until those land,
rotate by running `base64 -i <file>` locally, pasting the output into the
matching CircleCI context variable, and updating the source of truth under
`~/playola/playola-radio-ios/PlayolaRadio/Config/` on the release machine.
For the ASC API key and Match passphrase, update the CircleCI context
variable directly; there is no file to regenerate. After any rotation,
re-run the release workflow on a test tag to confirm CI can still sign and
upload.

Other developers can refresh their local xcconfig files from the release
machine's `~/playola/playola-radio-ios/PlayolaRadio/Config/` by running
`./scripts/setup-secrets.sh`. That script skips files that already exist,
so delete the stale xcconfig under `PlayolaRadio/Config/` first when
pulling a rotated value.
