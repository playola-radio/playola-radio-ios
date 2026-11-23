#!/usr/bin/env bash
# Factory demo environment for the iPhone app (see factory/DEMO.md).
#
#   scripts/demo-env.sh up     bring up the local backend if needed, build the Local app,
#                              install it on the "Playola Demo" simulator, sign it in, launch it
#   scripts/demo-env.sh down   delete the "Playola Demo" simulator (the backend keeps running)
#
# The app only ever talks to the demo server on this machine, and that server must answer the
# development-only dev-login endpoint, which production does not serve. Safe to re-run: every
# step reuses what already exists.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAYOLA_SERVER_DIR="${PLAYOLA_SERVER_DIR:-$HOME/playola/playola}"
# The server repo owns the demo backend's ports; read its API port so the two never drift apart.
DEMO_API_PORT="$(sed -n 's/^SERVER_PORT=//p' "$PLAYOLA_SERVER_DIR/docker/demo/compose.env" 2>/dev/null || true)"
DEMO_API_URL="http://localhost:${DEMO_API_PORT:-10070}"
SIMULATOR_NAME="Playola Demo"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
DERIVED_DATA="/tmp/playola-ios-demo-derived-data"
BUNDLE_ID="fm.playola.playolaradio"
BACKEND_TIMEOUT_SECONDS=900

fail() {
  echo "demo-env: $*" >&2
  exit 1
}

api_is_up() {
  curl -fs -m 5 -o /dev/null "$DEMO_API_URL/v1/health-check"
}

server_has_target() {
  [ -f "$PLAYOLA_SERVER_DIR/Makefile" ] && make -C "$PLAYOLA_SERVER_DIR" -n "$1" >/dev/null 2>&1
}

ensure_backend() {
  if api_is_up; then
    echo "Backend already up at $DEMO_API_URL"
    return
  fi
  server_has_target demo-env ||
    fail "nothing answers at $DEMO_API_URL and $PLAYOLA_SERVER_DIR has no 'make demo-env'. Set PLAYOLA_SERVER_DIR to a checkout of playola-radio/playola that has it, or start that repo's demo environment yourself."
  echo "Starting the local backend: make -C $PLAYOLA_SERVER_DIR demo-env"
  # The server's demo needs the read-replica URL the first time it downloads production data.
  # The subshell keeps those secrets out of the iOS build that runs afterwards.
  (
    if [ -f "$HOME/factory/secrets.env" ]; then
      set -a
      # shellcheck disable=SC1091
      . "$HOME/factory/secrets.env"
    fi
    make -C "$PLAYOLA_SERVER_DIR" demo-env
  )
  local waited=0
  until api_is_up; do
    [ "$waited" -lt "$BACKEND_TIMEOUT_SECONDS" ] || fail "backend did not answer at $DEMO_API_URL/v1/health-check within ${BACKEND_TIMEOUT_SECONDS}s"
    sleep 5
    waited=$((waited + 5))
  done
}

# Returns a token for the server's development admin user. Production and staging answer 404
# here, so getting a token is also the proof that this is a development server.
dev_login_token() {
  local response
  response="$(curl -fsS -m 30 -X POST "$DEMO_API_URL/v1/auth/dev-login")" ||
    fail "POST $DEMO_API_URL/v1/auth/dev-login failed; the demo only runs against a development server."
  python3 -c 'import json,sys; print(json.load(sys.stdin)["playolaToken"])' <<<"$response"
}

ensure_secrets() {
  [ -f "$ROOT/PlayolaRadio/Config/Secrets-Local.xcconfig" ] || make -C "$ROOT" setup-conductor
}

simulator_udid() {
  xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for device in devices:
        if device["name"] == name and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)
' "$SIMULATOR_NAME"
}

newest_ios_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
device_type = sys.argv[1]
runtimes = [
    r for r in json.load(sys.stdin)["runtimes"]
    if r["platform"] == "iOS" and r["isAvailable"]
    and any(t["identifier"] == device_type for t in r.get("supportedDeviceTypes", []))
]
if not runtimes:
    sys.exit("demo-env: no installed iOS runtime supports " + device_type)
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(runtimes[-1]["identifier"])
' "$DEVICE_TYPE"
}

ensure_simulator() {
  local udid
  udid="$(simulator_udid)"
  # This runs inside $(...), where bash 3.2 ignores set -e, so each step fails explicitly.
  if [ -z "$udid" ]; then
    local runtime
    runtime="$(newest_ios_runtime)" || fail "could not pick an iOS runtime"
    udid="$(xcrun simctl create "$SIMULATOR_NAME" "$DEVICE_TYPE" "$runtime")" ||
      fail "could not create the \"$SIMULATOR_NAME\" simulator"
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null || fail "could not boot simulator $udid"
  open -a Simulator --args -CurrentDeviceUDID "$udid" || fail "could not open Simulator"
  echo "$udid"
}

build_app() {
  local udid="$1"
  # DEV_ENVIRONMENT=local pins the build to localhost whatever the xcconfig says, LOCAL_API_URL
  # points it at the demo server, and the placeholder Mixpanel token keeps demo sessions out of
  # the real analytics project.
  xcodebuild build \
    -project "$ROOT/PlayolaRadio.xcodeproj" \
    -scheme PlayolaRadio-Local \
    -configuration Local-Debug \
    -destination "id=$udid" \
    -derivedDataPath "$DERIVED_DATA" \
    -skipPackagePluginValidation \
    -quiet \
    DEV_ENVIRONMENT=local \
    LOCAL_API_URL="$DEMO_API_URL" \
    MIXPANEL_TOKEN=demo-environment-no-analytics
}

write_session() {
  local udid="$1" token="$2" container
  container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)"
  mkdir -p "$container/Documents"
  python3 -c '
import base64, json, sys
token = sys.argv[1]
payload = token.split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
user = {key: claims.get(key) for key in
        ("id", "firstName", "lastName", "email", "verifiedEmail", "profileImageUrl", "role")}
user["jwt"] = token
print(json.dumps({"currentUser": user, "jwt": token}))
' "$token" >"$container/Documents/auth.json"
  chmod 600 "$container/Documents/auth.json"
}

up() {
  ensure_backend
  local token udid
  token="$(dev_login_token)"
  ensure_secrets
  udid="$(ensure_simulator)"
  echo "Building PlayolaRadio-Local against $DEMO_API_URL"
  build_app "$udid"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$DERIVED_DATA/Build/Products/Local-Debug-iphonesimulator/PlayolaRadio.app"
  write_session "$udid" "$token"
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
  cat <<EOF

Demo environment ready.
  Record at: simulator "$SIMULATOR_NAME" ($udid), app $BUNDLE_ID (PlayolaRadio-Local), signed in
  Backend:   $DEMO_API_URL
  Record:    xcrun simctl io $udid recordVideo --codec h264 demo.mp4   (Ctrl-C to stop)
EOF
}

down() {
  local udid
  udid="$(simulator_udid)"
  if [ -n "$udid" ]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid"
    echo "Deleted simulator \"$SIMULATOR_NAME\" ($udid)"
  fi
  # Other demos may share the backend, so it is left running.
  echo "The demo backend is still up. To stop it and drop its data: make -C $PLAYOLA_SERVER_DIR demo-env-down"
}

case "${1:-}" in
up) up ;;
down) down ;;
*) fail "usage: scripts/demo-env.sh up|down" ;;
esac
