#!/bin/bash
# Double-click this file to build Rox Daily and install it on the iPhone plugged in over USB.
# Needs Xcode 16+ with your Apple ID added under Xcode > Settings > Accounts.
cd "$(dirname "$0")" || exit 1
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
fallback() {
  say "$1"
  echo "Opening the project in Xcode instead. There: select the RoxDaily target, open"
  echo "Signing & Capabilities, pick your Team, choose your iPhone at the top, press Run."
  [ -n "${ROX_NO_OPEN:-}" ] || open RoxDaily.xcodeproj
  exit "${2:-1}"
}

command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1 \
  || { say "Xcode is not installed. Get it free from the Mac App Store, open it once, then run this again."; exit 1; }

say "1/4 Looking for your iPhone..."
JSON=$(mktemp)
xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1
read -r DEVICE UDID NAME <<<"$(python3 - "$JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("deviceType") == "iPhone" and hw.get("reality", "physical") == "physical" \
            and conn.get("tunnelState") != "unavailable" and hw.get("udid"):
        name = d.get("deviceProperties", {}).get("name", "iPhone").replace(" ", "_")
        print(d.get("identifier", ""), hw["udid"], name)
        break
PY
)"
rm -f "$JSON"
[ -n "${UDID:-}" ] || fallback "No iPhone found. Plug it in with a cable, unlock it, tap Trust, then run this again."
echo "Found ${NAME//_/ }."

say "2/4 Finding your Apple ID team..."
TEAM="${1:-}"
[ -n "$TEAM" ] || TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | sed -n 's/.*teamID = \([A-Z0-9]\{10\}\);.*/\1/p' | head -1)
[ -n "$TEAM" ] || TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)
[ -n "$TEAM" ] || fallback "No Apple ID found in Xcode. Add yours under Xcode > Settings > Accounts."
echo "Using team $TEAM."

say "3/4 Building (a few minutes the first time)..."
rm -rf build/Build/Products/Debug-iphoneos
xcodebuild -project RoxDaily.xcodeproj -scheme RoxDaily -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM="$TEAM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
APP="build/Build/Products/Debug-iphoneos/RoxDaily.app"
[ -d "$APP" ] || fallback "The build did not finish. Xcode will show the reason."

say "4/4 Installing on ${NAME//_/ }..."
xcrun devicectl device install app --device "$DEVICE" "$APP" || fallback "Install failed. Keep the phone unlocked and try again."
xcrun devicectl device process launch --device "$DEVICE" com.roxdaily.trainer.k7q2 >/dev/null 2>&1 \
  || echo "Installed. If it will not open: on the phone go to Settings > General > VPN & Device Management and trust your developer certificate, then tap the Rox Daily icon."
say "Done. Rox Daily is on your iPhone."
