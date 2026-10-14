# Staging Builds

The **Nightly Staging Build** GitHub Action (`.github/workflows/nightly-staging.yml`) builds the
`develop` tip and uploads it to the **staging** TestFlight app (`fm.playola.playolaradio.staging`),
internal testers only. It runs daily at 08:00 UTC and can be started by hand at any time.

## Build develop to staging now

```bash
gh workflow run nightly-staging.yml --ref develop
```

A manual run always builds, even if this commit was already built. Use it after merging a PR you
want to test on staging instead of waiting for the night.

## Check that it started

The Action only asks CircleCI to start the build; it finishes in ~10s. The real build
(`release_staging_build` job) runs on CircleCI.

```bash
gh run list --workflow nightly-staging.yml --limit 1          # the trigger run
gh run view <run-id> --log | grep "CircleCI responded HTTP [0-9]" -A3   # HTTP 201 + pipeline number
```

Grep for the digit: the log also prints the script source, so a bare `::error::` match is not a
failure. Then follow the pipeline number in CircleCI (project `gh/playola-radio/playola-radio-ios`,
branch `develop`), or use the CircleCI MCP `get_latest_pipeline_status` with that slug and branch.

## Limits

- **Only `develop`.** The workflow hard-codes `develop` for both the checkout and the CircleCI
  request, so a PR branch can't be built to staging before it merges.
- The CircleCI MCP `run_pipeline` tool can't set the `run_nightly_staging` pipeline parameter, so it
  can't start a staging build either — a plain pipeline on a branch only runs lint/tests.
- Production TestFlight builds come from a merge to `main` (the Auto-Tag Release Action tags it and
  triggers the `release` workflow), not from this Action.
