#!/bin/zsh
# Apple TV App Store screenshots from the app in the tvOS simulator (a Debug build: its -showMenu and -recite
# launch arguments), in English, French and Arabic, into ../ios-assets/appstore-assets/tv/<lang>/.
set -uo pipefail
cd "$(dirname "$0")"
APP="$1"   # the simulator build's Mushaf.app
OUT=../ios-assets/appstore-assets/tv
ID=com.kousa.mushaf
# A fresh Apple TV 4K simulator on the newest tvOS runtime installed (the workflow downloads it).
RUNTIME=$(xcrun simctl list runtimes available | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.tvOS-[0-9-]+' | tail -1)
TYPE=$(xcrun simctl list devicetypes | grep -E "Apple TV 4K" | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9-]+' | tail -1)
[ -n "$RUNTIME" ] && [ -n "$TYPE" ] || { echo "No tvOS runtime or Apple TV device type"; xcrun simctl list runtimes; exit 1; }
UDID=$(xcrun simctl create "Mushaf TV" "$TYPE" "$RUNTIME") || exit 1
echo "Simulator: $UDID ($TYPE, $RUNTIME)"
xcrun simctl boot "$UDID" || exit 1
xcrun simctl bootstatus "$UDID" -b || exit 1
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null
sleep 20
xcrun simctl install "$UDID" "$APP" || exit 1

shot() {  # shot <file> <wait> <launch arguments...>
  local file=$1 wait=$2; shift 2
  xcrun simctl terminate "$UDID" $ID 2>/dev/null
  xcrun simctl launch "$UDID" $ID "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$file" >/dev/null && echo "$file"
}

for lang in en fr ar; do
  mkdir -p "$OUT/$lang"
  shot "$OUT/$lang/01.png" 30 -language $lang -page 1 -night NO
  shot "$OUT/$lang/02.png" 30 -language $lang -page 293 -night NO -recite YES
  shot "$OUT/$lang/03.png" 25 -language $lang -page 50 -night YES
  shot "$OUT/$lang/04.png" 20 -language $lang -page 1 -night NO -showMenu YES
done
xcrun simctl terminate "$UDID" $ID 2>/dev/null
