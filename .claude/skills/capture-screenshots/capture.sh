#!/usr/bin/env bash
#
# Helper for the capture-screenshots skill. Automates the fiddly, error-prone
# parts of grabbing App Store screenshots from the iOS simulator:
#   - resolving a UNIQUE simulator UDID (device-type names are not unique — there
#     are many "iPhone 16 Pro Max" instances, so a bare name errors)
#   - booting + waiting for boot
#   - overriding the status bar to a clean marketing state (9:41, full bars)
#   - building/installing the production app (pinned to the CI Xcode)
#   - capturing correctly-named files into fastlane/screenshots/en-US/
#
# You still navigate the app BY HAND between captures — it is auth-gated and has
# no deep links, so there is no way to script the navigation.
#
# Usage:
#   ./capture.sh setup [--no-build]   # boot both sims, clean status bar, build+install
#   ./capture.sh iphone <N>           # capture iPhone sim  -> N_APP_IPHONE_67_N.png
#   ./capture.sh ipad   <N>           # capture iPad sim    -> N_APP_IPAD_PRO_3GEN_129_N.png
#   ./capture.sh clean                # clear the status-bar overrides
#
# Override the output dir for testing: CAPTURE_SHOTS_DIR=/tmp/shots ./capture.sh iphone 0
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHOTS_DIR="${CAPTURE_SHOTS_DIR:-$REPO/fastlane/screenshots/en-US}"
DEVELOPER_DIR_PATH="/Applications/Xcode-26.5.0.app/Contents/Developer"
IPHONE_TYPE="iPhone 16 Pro Max"                     # 1320x2868 (App Store 6.9")
IPAD_TYPE="iPad Pro (12.9-inch) (6th generation)"   # 2048x2732 (App Store 12.9")
BUNDLE_ID="fm.playola.playolaradio"
SCHEME="PlayolaRadio"

UUID_RE='[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'

udid_for() { # $1 = device-type name; prefer a BOOTED instance, else first available.
  # Preferring booted matters when duplicates exist (e.g. an old-OS copy of the
  # same device sitting alongside the one setup booted) — otherwise capture could
  # target the wrong, app-less simulator.
  local u
  u="$(xcrun simctl list devices booted | grep -F "$1 (" | grep -oE "$UUID_RE" | head -1)"
  [ -n "$u" ] || u="$(xcrun simctl list devices available | grep -F "$1 (" | grep -oE "$UUID_RE" | head -1)"
  printf '%s' "$u"
}

require_udid() { # $1 = type name; prints udid or fails loudly
  local u; u="$(udid_for "$1")"
  [ -n "$u" ] || { echo "ERROR: no available '$1' simulator found (xcrun simctl list devices)"; exit 1; }
  printf '%s' "$u"
}

clean_status_bar() { # $1 = udid
  xcrun simctl status_bar "$1" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
}

cmd_setup() {
  local iphone ipad
  iphone="$(require_udid "$IPHONE_TYPE")"
  ipad="$(require_udid "$IPAD_TYPE")"
  echo "iPhone: $IPHONE_TYPE -> $iphone"
  echo "iPad:   $IPAD_TYPE -> $ipad"

  xcrun simctl boot "$iphone" 2>/dev/null || true
  xcrun simctl boot "$ipad" 2>/dev/null || true
  open -a Simulator
  xcrun simctl bootstatus "$iphone" -b
  xcrun simctl bootstatus "$ipad" -b
  clean_status_bar "$iphone"
  clean_status_bar "$ipad"

  if [ "${1:-}" != "--no-build" ]; then
    # Release, NOT Debug: Debug bakes DEV_ENVIRONMENT=development, so the app talks
    # to the dev backend — production sign-in fails silently and the content is
    # wrong for the store. Release = the App Store production environment.
    echo "Building $SCHEME (Release/production) with Xcode 26.5 (a few minutes)…"
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcodebuild \
      -project "$REPO/PlayolaRadio.xcodeproj" \
      -scheme "$SCHEME" -configuration Release \
      -destination "platform=iOS Simulator,id=$iphone" \
      -derivedDataPath "$REPO/build" \
      -skipPackagePluginValidation -skipMacroValidation \
      CODE_SIGNING_ALLOWED=NO build
    local app="$REPO/build/Build/Products/Release-iphonesimulator/PlayolaRadio.app"
    for u in "$iphone" "$ipad"; do
      xcrun simctl install "$u" "$app"
      xcrun simctl launch "$u" "$BUNDLE_ID"
    done
  fi

  echo
  echo "Ready. Now, on EACH simulator: sign in with a real Playola account so the"
  echo "screens populate with live data. Then navigate to a screen and capture:"
  echo "  ./capture.sh iphone 0   (Home)   … iphone 4"
  echo "  ./capture.sh ipad 0     … ipad 1"
}

cmd_iphone() {
  local n="$1" u; u="$(require_udid "$IPHONE_TYPE")"
  mkdir -p "$SHOTS_DIR"; clean_status_bar "$u"
  xcrun simctl io "$u" screenshot "$SHOTS_DIR/${n}_APP_IPHONE_67_${n}.png"
  echo "wrote ${n}_APP_IPHONE_67_${n}.png ($(sips -g pixelWidth -g pixelHeight "$SHOTS_DIR/${n}_APP_IPHONE_67_${n}.png" 2>/dev/null | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}'))"
}

cmd_ipad() {
  local n="$1" u; u="$(require_udid "$IPAD_TYPE")"
  mkdir -p "$SHOTS_DIR"; clean_status_bar "$u"
  xcrun simctl io "$u" screenshot "$SHOTS_DIR/${n}_APP_IPAD_PRO_3GEN_129_${n}.png"
  echo "wrote ${n}_APP_IPAD_PRO_3GEN_129_${n}.png ($(sips -g pixelWidth -g pixelHeight "$SHOTS_DIR/${n}_APP_IPAD_PRO_3GEN_129_${n}.png" 2>/dev/null | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}'))"
}

cmd_clean() {
  local u
  for t in "$IPHONE_TYPE" "$IPAD_TYPE"; do
    u="$(udid_for "$t")"; [ -n "$u" ] && xcrun simctl status_bar "$u" clear 2>/dev/null || true
  done
  echo "status bars cleared"
}

case "${1:-}" in
  setup)  shift; cmd_setup "${1:-}" ;;
  iphone) cmd_iphone "${2:?usage: capture.sh iphone N}" ;;
  ipad)   cmd_ipad "${2:?usage: capture.sh ipad N}" ;;
  clean)  cmd_clean ;;
  *) echo "usage: capture.sh {setup [--no-build] | iphone N | ipad N | clean}"; exit 1 ;;
esac
