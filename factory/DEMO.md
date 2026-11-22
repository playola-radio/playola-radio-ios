# Demo Environment

## What this is

One safe, local instance of the iPhone app for recording a demo video: this checkout's
`PlayolaRadio-Local` build running on a dedicated simulator named **Playola Demo**, signed in,
talking only to the Playola server's own demo environment on this machine (a local copy of
production data). Nothing in it reaches a deployed server, so a demo can tap, save and delete
freely.

Why this build and no other:

- `PlayolaRadio` (Debug) talks to the production API, and `PlayolaRadio-Staging` still sends
  source-tape uploads to the production API. Neither is used here.
- `PlayolaRadio-Local` sends every request to `localhost`. `make demo-env` builds it with
  `LOCAL_API_URL` set to the demo server, and checks that address is `localhost`.
- The app signs in through the server's `POST /v1/auth/dev-login`, which only a development
  server has (production and staging answer 404). If that call fails, `make demo-env` stops
  before installing anything.
- The demo build uses a placeholder Mixpanel token, so demo taps stay out of the real analytics.

## Prerequisites

- Xcode 27 with an iOS simulator runtime (the newest installed one is used), `python3`, `curl`.
- The `Secrets*.xcconfig` files in `PlayolaRadio/Config/`. If `Secrets-Local.xcconfig` is
  missing, `make demo-env` runs `make setup-conductor`, which copies them from
  `~/playola/playola-radio-ios`.
- A checkout of the server repo (`playola-radio/playola`) that has `make demo-env`, at
  `~/playola/playola` or wherever `PLAYOLA_SERVER_DIR` points. Its own `factory/DEMO.md` lists
  what it needs: Docker (colima), and one secret the first time it downloads production data:
  - `RENDER_PRODUCTION_FOLLOWER_DB_URL`: the **external** connection string of the production
    **read replica** (Render dashboard → the production Postgres read replica → Connect →
    External). Put it in `~/factory/secrets.env` (sourced by the factory, never committed):

    ```bash
    RENDER_PRODUCTION_FOLLOWER_DB_URL=postgres://...
    ```

This repo itself needs no secret beyond the `Secrets*.xcconfig` files above.

## Bring it up

```bash
make demo-env
```

It:

1. Uses the demo backend if it already answers at `http://localhost:10120/v1/health-check`;
   otherwise runs `make -C $PLAYOLA_SERVER_DIR demo-env` (downloads and restores production
   data the first time, starts the server) and waits for it.
2. Gets a token from the backend's dev-login (the development admin user).
3. Creates (once) and boots the **Playola Demo** simulator (iPhone 17 Pro) and opens Simulator.
4. Builds `PlayolaRadio-Local` into `/tmp/playola-ios-demo-derived-data`, installs it, writes the
   signed-in session into the app, and launches it.

Re-running it is safe: the simulator, the build and the backend are reused, and the session is
rewritten. Override `DEMO_API_URL` (default `http://localhost:10120`; must be `localhost`) or
`PLAYOLA_SERVER_DIR` if yours differ.

**Record at:** the **Playola Demo** simulator, app `fm.playola.playolaradio`
(`PlayolaRadio-Local`), signed in, against `http://localhost:10120`. `make demo-env` prints the
simulator's id and a ready-made recording command:

```bash
xcrun simctl io <udid> recordVideo --codec h264 demo.mp4   # Ctrl-C to stop
```

Never open the profile tab or any screen with the account's name or email in a recording.

## Data

- **Source:** the server's demo database, `playola_demo`, restored from a `pg_dump` of the
  production **read replica**. The dump is read-only on production's side; the restore goes into
  a local Postgres. No seed data is involved, so stations, schedules and artwork look real.
- **Why it's safe:** the app's only server is the local one (checked by URL and by dev-login).
  The server's demo overlay blanks every outbound credential (email, push, AWS, OpenAI,
  reporting), so nothing done in the demo reaches a listener or a third party. Audio and artwork
  still stream from their public URLs, read-only.
- **Isolation:**
  - Simulator: its own device, **Playola Demo**, separate from any simulator you develop or run
    UX evidence on.
  - Build: its own derived data at `/tmp/playola-ios-demo-derived-data`.
  - Backend (owned by the server repo, whose `factory/DEMO.md` is the reference): Docker
    Compose project `playola-demo`, database `playola_demo`, API on `10120`, Postgres on
    `127.0.0.1:5442`, so it never collides with a dev server on `10020` or another repo's
    Postgres on `5432`/`5433`.
- **Known limits:**
  - Crash and error reports still go to Sentry, as they do from any local build. A demo that
    hits an error shows up there.
  - Source-tape uploads go to `localhost:11020`, which the demo backend doesn't serve, so
    don't demo that flow.

## Reset / tear down

```bash
make demo-env-down
```

Deletes the **Playola Demo** simulator (and with it the app and its session) and runs the server
repo's `make demo-env-down` to stop the backend. The next `make demo-env` starts from scratch.
