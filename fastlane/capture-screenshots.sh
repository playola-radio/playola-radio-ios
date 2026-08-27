#!/bin/bash
# Captures the App Store screenshot set from the ScreenshotHarness (see
# PlayolaRadio/ScreenshotHarness.swift). Run from the repo root.
#
# Build the Debug app first:
#   DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
#     xcodebuild -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
#     -configuration Debug -destination "platform=iOS Simulator,id=$SIM" \
#     -derivedDataPath build -skipPackagePluginValidation -skipMacroValidation build
#
# Output names follow the fastlane deliver convention (N_APP_IPHONE_67_N.png)
# so `fastlane deliver` picks them up from fastlane/screenshots/en-US.
set -euo pipefail
SIM="${SCREENSHOT_SIM:-8DD1E461-F822-4CE6-80EB-AC52CA49959A}"  # iPhone 16 Pro Max (iOS 26.5)
APP="build/Build/Products/Debug-iphonesimulator/PlayolaRadio.app"
BUNDLE=fm.playola.playolaradio
OUT="fastlane/screenshots/en-US"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
xcrun simctl install "$SIM" "$APP"
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
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
