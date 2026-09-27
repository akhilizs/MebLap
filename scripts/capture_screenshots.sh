#!/usr/bin/env bash
# Installs the simulator build and captures each screen via screenshot mode.
set -euo pipefail

APP=build/Build/Products/Debug-iphonesimulator/MebLap.app
BUNDLE=com.meblap.app
OUT=screenshots
mkdir -p "$OUT"

codesign --force --deep --sign - "$APP"
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location "$BUNDLE" || true
xcrun simctl privacy "$UDID" grant location-always "$BUNDLE" || true
xcrun simctl location "$UDID" set 33.8938,35.5018   # Beirut (Hamra)

shoot() {
  local scene=$1 wait=$2
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -MebLapScreenshot "$scene" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$scene.png" >/dev/null
  echo "captured $scene"
}

# Warm-up launch so map tiles and fonts are cached.
xcrun simctl launch "$UDID" "$BUNDLE" -MebLapScreenshot map >/dev/null
sleep 20

shoot map 12
shoot search 8
shoot place 12
shoot route 18
shoot navigation 20
shoot report 8
shoot passes 18
shoot roadConditions 14
shoot emergency 8
shoot tripCost 18
shoot settings 6
