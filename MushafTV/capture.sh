#!/bin/zsh
# Apple TV App Store screenshots from the app in the tvOS simulator (a Debug build: its -showMenu and -recite
# launch arguments), in English, French and Arabic, into ../ios-assets/appstore-assets/tv/<lang>/.
set -uo pipefail
cd "$(dirname "$0")"
APP="$1"   # the simulator build's Mushaf.app
OUT=../ios-assets/appstore-assets/tv
ID=com.kousa.mushaf
UDID=$(xcrun simctl list devices available | grep -m1 -E "Apple TV 4K" | grep -oE '[0-9A-F-]{36}')
[ -n "$UDID" ] || UDID=$(xcrun simctl list devices available | grep -m1 "Apple TV" | grep -oE '[0-9A-F-]{36}')
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

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
