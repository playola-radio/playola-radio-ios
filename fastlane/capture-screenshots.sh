#!/bin/bash
# Captures the App Store screenshot set from the ScreenshotHarness (see
# PlayolaRadio/ScreenshotHarness.swift). Run from the repo root.
#
# Build the Debug app first:
#   DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
#     xcodebuild -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
#     -configuration Debug \
#     -destination "platform=iOS Simulator,name=iPhone 16 Pro Max" \
#     -derivedDataPath build -skipPackagePluginValidation -skipMacroValidation build
#
# Output names follow the fastlane deliver convention (N_APP_IPHONE_67_N.png)
# so `fastlane deliver` picks them up from fastlane/screenshots/en-US.
set -euo pipefail
# Capture on an iPhone 16 Pro Max (6.7"/6.9" class for App Store 67 shots).
# Set SCREENSHOT_SIM=<udid> to pin a specific simulator.
if [ -n "${SCREENSHOT_SIM:-}" ]; then
  SIM="$SCREENSHOT_SIM"
else
  # Prefer an already-booted match; otherwise take the last listed, which
  # falls in the newest iOS runtime section of `simctl list`.
  MATCHES=$(xcrun simctl list devices available | grep "iPhone 16 Pro Max (" || true)
  SIM=$(echo "$MATCHES" | grep "(Booted)" | head -1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()' || true)
  if [ -z "$SIM" ]; then
    SIM=$(echo "$MATCHES" | tail -1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()' || true)
  fi
fi
if [ -z "$SIM" ]; then
  echo "No available iPhone 16 Pro Max simulator found; set SCREENSHOT_SIM=<udid>" >&2
  exit 1
fi
echo "Using simulator $SIM"
APP="build/Build/Products/Debug-iphonesimulator/PlayolaRadio.app"
BUNDLE=fm.playola.playolaradio
OUT="fastlane/screenshots/en-US"
# Clean up even when a capture step fails mid-run: the status-bar override and
# the harness's fake persisted account must not outlive the script. Uninstall
# only once the fixture app was actually installed.
INSTALLED=0
cleanup() {
  if [ "$INSTALLED" = 1 ]; then
    xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
    xcrun simctl uninstall "$SIM" "$BUNDLE" 2>/dev/null || true
  fi
  xcrun simctl status_bar "$SIM" clear 2>/dev/null || true
}
trap cleanup EXIT
xcrun simctl bootstatus "$SIM" -b
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
xcrun simctl install "$SIM" "$APP"
INSTALLED=1
capture() {
  local page=$1 name=$2
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  sleep 2
  SIMCTL_CHILD_SCREENSHOT_PAGE=$page xcrun simctl launch "$SIM" "$BUNDLE"
  sleep 12
  xcrun simctl io "$SIM" screenshot "$OUT/$name"
  echo "captured $page -> $name"
}
capture home 0_APP_IPHONE_67_0.png
capture player 1_APP_IPHONE_67_1.png
capture player-tap 2_APP_IPHONE_67_2.png
capture stations 3_APP_IPHONE_67_3.png
capture library 4_APP_IPHONE_67_4.png
