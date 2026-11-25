#!/bin/bash
# Builds Rox Daily and installs it on the iPhone plugged in over USB.
# Requires Xcode 16+, with your Apple ID added under Xcode > Settings > Accounts.
set -euo pipefail
cd "$(dirname "$0")"

TEAM="${1:-}"
if [ -z "$TEAM" ]; then
  TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [ -z "$TEAM" ]; then
  echo "No signing team found. Opening Xcode instead: pick your Team under Signing & Capabilities, then press Run."
  open RoxDaily.xcodeproj
  exit 0
fi

rm -rf build/Build/Products/Debug-iphoneos
echo "Building with team $TEAM..."
xcodebuild -project RoxDaily.xcodeproj -scheme RoxDaily -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" build | grep -E "error|BUILD" || true

APP=$(find build/Build/Products/Debug-iphoneos -maxdepth 1 -name RoxDaily.app 2>/dev/null | head -1 || true)
[ -n "$APP" ] || { echo "Build failed. Open RoxDaily.xcodeproj in Xcode to see why."; exit 1; }

DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && !/unavailable/ && /connected|available/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{36}$/) {print $i; exit}}')
[ -n "$DEVICE" ] || { echo "No iPhone found. Plug it in, unlock it, tap Trust, then run this again."; exit 1; }

xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "Installed. On the phone, trust your developer certificate under Settings > General > VPN & Device Management if asked."
