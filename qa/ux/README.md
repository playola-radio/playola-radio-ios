# UX evidence (iPhone app)

Records before/after screenshots (`visual` cases) or videos (`functional` cases) of a change to the iPhone app and attaches them to the PR. One device (iPhone 17 Pro, iOS 27.0 simulator, light appearance, status bar fixed at 9:41), against the staging server, signed in with a saved staging session.

## Setup

The tool lives in the shared skills repo, [`playola-radio/ai-skills`](https://github.com/playola-radio/ai-skills), under `ux-evidence/tool/`, so the web app and the iPhone app use one copy. This repo keeps only its cases (`qa/ux/<case-id>/`) and `qa/ux/config.yaml` (build, device and tool settings).

- Node 24 or newer.
- The skills repo cloned at `~/playola/playola-skills` (`git pull` there to update the tool). To use a checkout elsewhere, set `UX_EVIDENCE_HOME` to its `ux-evidence/tool` folder, e.g. `make ux-evidence-verify UX_EVIDENCE_HOME=/path/to/ux-evidence/tool`.
- `make ux-evidence-setup` (installs the tool's packages in the tool folder). Rerun it after the tool's packages change.
- Xcode at the `xcodePath` in `qa/ux/config.yaml`, with the iOS 27.0 simulator runtime installed (Xcode > Settings > Components).
- Maestro at `~/.maestro/bin/maestro` (`curl -fsSL https://get.maestro.mobile.dev | bash`) and Java 17 at `/opt/homebrew/opt/openjdk@17` (`brew install openjdk@17`).
- ffmpeg on your `PATH`.
- `gh` 2.104.0 or newer (for `publish`).
- The four `Secrets*.xcconfig` files in `PlayolaRadio/Config/` of the checkout named by `secretsSource` (normally `~/playola/playola-radio-ios`). They are copied into each build by name and never read or printed.
- A saved staging session (below).

### The staging session

Each recording installs the Staging app on a fresh simulator and signs it in by writing a saved session into the app's data, so flows start signed in without typing a password.

1. In any simulator, run the Staging app and sign in.
2. With that simulator still booted, run:

   ```bash
   make ux-evidence-ios-login
   ```

   If more than one booted simulator has the Staging app, pick one: `make ux-evidence-ios-login DEVICE=<udid>` (`xcrun simctl list devices booted` shows the ids).

It only reads from that simulator. It checks the session with one request to the staging server, saves it to `~/.config/playola-ux/ios-staging-auth.json` (readable only by you), and prints the path, the expiry (or `expiry: not supplied`) and `session validated`. Every recording checks it again first; when the server rejects it, or it expires within 30 minutes, sign in again and rerun the command. Never copy the file anywhere: staging sessions also work on production.

## When evidence is needed

If the branch changes anything under `PlayolaRadio/` or `PlayolaRadio.xcodeproj/`, either `make ux-evidence-verify` passes before the PR is opened, or the PR body contains `UX evidence: none — <reason>` (for changes with no visible effect). Test files and `*.md` do not count as changes. The publish step and the re-verify-after-push step apply only when the branch has evidence cases; a PR using `UX evidence: none — <reason>` skips both.

## A case

```text
qa/ux/<case-id>/
  evidence.yaml
  setup.yaml      # optional
  flow.yaml
```

```yaml
version: 1
id: stations-list-spacing       # must equal the folder name
classification: visual          # visual (screenshots) | functional (video)
before:
  policy: required              # required | not-applicable
  reason: ...                   # required text when not-applicable
```

Create one with:

```bash
make ux-evidence-new CASE=<case-id> CLASSIFICATION=<visual|functional> BEFORE=<required|not-applicable> [REASON="..."]
```

It writes `evidence.yaml`, `setup.yaml` and `flow.yaml`. The new `flow.yaml` fails on purpose (`write your flow in qa/ux/<case-id>/flow.yaml`) until you replace its last step. Case ids are lowercase letters, digits and hyphens. `qa/ux/example-stations/` (visual) and `qa/ux/example-navigation/` (functional) are worked examples.

## The flow

`setup.yaml` and `flow.yaml` are [Maestro](https://docs.maestro.dev) flows. Each starts with the app id header:

```yaml
appId: fm.playola.playolaradio.staging
---
- tapOn: "Radio Stations"
```

- The tool launches the app (keeping the injected session, and denying every system permission prompt so none covers the screen), runs `setup.yaml` if present, then `flow.yaml`. Both revisions run the same files from your current checkout.
- `setup.yaml` gets the app to the starting screen and dismisses first-launch prompts. On a fresh install the app asks "Stay in the Loop?" after the first screen; the example taps "No Thanks", which only saves a local setting.
- A visual case's `flow.yaml` must have at least one `takeScreenshot: <name>` step. Names are lowercase letters, digits and hyphens, each used once; saved as `before-<name>.png` / `after-<name>.png`. Base and head must produce the same names.
- A functional case's video shows `flow.yaml` only. Recording starts once setup has finished and the recorder reports it is recording (the flow's first step waits for that), and stops once the flow's last step has finished, so the video opens on the screen setup left and ends on the flow's final screen. Make `setup.yaml` leave the app on the flow's first screen with every prompt dismissed. The video is H.264 with no audio and must be at most 10 MiB (10,485,760 bytes); keep flows short.
- Never build or record the production app. The tool refuses any app or server other than the Staging ones.
- The session is the owner's own staging account, so a flow may open the profile tab and switch to broadcasting mode (the only way to the Station tab; it is forgotten on relaunch, so do it in `setup.yaml`).
- No fixed sleeps. Wait with `extendedWaitUntil: { visible: "<text>", timeout: 30000 }` on text that appears on screen once it has loaded. Do not match station names or other staging data that can change.
- A flow may create and change things on staging.

## Commands

Use this command to check the setup with the example case against the merge base with `origin/develop` ("before") and the current `HEAD` ("after"). The example is expected to be identical, so `ALLOW_IDENTICAL=1` prevents that expected result from failing the setup check; do not use it for real visual changes.

```bash
make ux-evidence CASE=example-stations ALLOW_IDENTICAL=1
```

It refuses to run with uncommitted changes under `PlayolaRadio/`, `PlayolaRadio.xcodeproj/` or `qa/ux/<case-id>/`. Each revision is checked out into a temporary git worktree under `~/.cache/playola-ux/ios/` and built for the simulator (Swift packages are cached in `~/.cache/playola-ux/ios/spm`); then each is installed on a new simulator the run creates and deletes. Only one iOS recording runs at a time per machine. A run removes its own simulators, worktrees and temp directory on exit, including on Ctrl-C (which stops xcodebuild or Maestro first). It never touches a simulator it did not create.

A failed "before" build stops the run and keeps the build log at `.qa-artifacts/<case-id>/build-before.log` (`build-after.log` for the head).

When every before/after screenshot pair is pixel-identical, the run fails:

```text
no visible difference: every before/after screenshot of <case-id> is identical. ...
```

That means the case does not show the change, or the change has no visible effect (then use `UX evidence: none — <reason>` in the PR body instead). `make ux-evidence CASE=<id> ALLOW_IDENTICAL=1` skips the gate, adds `"identical": true` to `result.json` and a note to the comment. Use it only for the example case and for testing the tool, never to get a real PR's evidence through.

Check that evidence is current for the checked-out `HEAD`:

```bash
make ux-evidence-verify
```

Exit 0 means current. Otherwise it prints which case is stale or missing and why.

Attach the results to the PR, one comment per case:

```bash
make ux-evidence-publish PR=123
```

It runs `verify` first and refuses if evidence is stale. Re-recording after a later push posts a new comment; old ones stay.

## `before: not-applicable`

Use it only when no "before" exists on the base commit: the screen or feature is new. It skips the base build and run and needs a reason, which appears in the PR comment. A base that fails to build or run is not "not-applicable". Fix the flow rather than switching policy.

## Output

`.qa-artifacts/<case-id>/` (git-ignored):

```text
before-<shot>.png  after-<shot>.png  compare-<shot>.png   # visual
before.mp4  after.mp4                                    # functional
result.json  comment.md
```

## Troubleshooting

- "UX evidence tool missing": clone `playola-radio/ai-skills` to `~/playola/playola-skills`, or set `UX_EVIDENCE_HOME`, then run `make ux-evidence-setup`.
- "no saved staging session", "rejected the saved session" or "expires … less than 30 minutes from now": sign in to the Staging app in a simulator and run `make ux-evidence-ios-login`.
- "missing Secrets….xcconfig": copy the four files into `secretsSource`'s `PlayolaRadio/Config/` (see `make setup-conductor`).
- "simulator runtime … is not installed" or "cannot run …": install the runtime named in `qa/ux/config.yaml`, or change `ios.runtime` / `ios.deviceType`.
- "another iOS recording is running (pid N)": wait for it. A lock left by a process that has exited is taken over automatically.
- "the simulator video recorder did not start within 8 s" or "simctl recordVideo failed": the recorder could not capture the simulator's screen; rerun, and if it repeats, check that the Xcode in `qa/ux/config.yaml` can run `xcrun simctl io <udid> recordVideo` on a booted simulator.
- "the Maestro flow failed": the last lines of Maestro's output are printed; usually a `tapOn` or `extendedWaitUntil` text that did not appear.
- Leftovers after a hard kill (kill -9, power loss): `xcrun simctl list devices | grep playola-ux-` then `xcrun simctl delete <udid>` for each, `git worktree prune`, and delete everything in `~/.cache/playola-ux/ios/` except `spm`.

## Measured run time

`make ux-evidence CASE=example-stations` on an Apple-silicon Mac with Xcode 27.1, measured 2026-11-16:

- First run (empty package cache): 558 s (about 9½ minutes).
- Second run (package cache warm): 537 s (about 9 minutes).

About seven minutes of that is the two app builds (before and after), each from a clean build folder,
so a warm package cache saves little. Each capture (create a simulator, install, sign in, screenshot,
delete the simulator) takes under two minutes.

`make ux-evidence CASE=example-navigation` (functional, video), same Mac, measured 2026-11-16: 520 s
(about 8½ minutes); five runs took 520–795 s on a heavily loaded machine. Its two videos are about 6½ s long
and about 370 KB each (`before.mp4` 368,263 bytes, `after.mp4` 367,004 bytes), far under the 10 MiB limit.
Recording the video adds only seconds to a capture; the builds still dominate.
