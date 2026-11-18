#!/bin/zsh
# Apple TV App Store screenshots from the app in the tvOS simulator (a Debug build: its -screen launch
# argument), in English, French and Arabic, into ../ios-assets/appstore-assets/tv/<lang>/.
set -uo pipefail
cd "$(dirname "$0")"
APP="$1"   # the simulator build's Mushaf.app
OUT=../ios-assets/appstore-assets/tv
ID=com.kousa.mushaf
# An Apple TV 4K simulator (not the 1080p one) on the newest tvOS runtime installed.
UDID=$(xcrun simctl list -j devices available | python3 -c '
import json, sys, re
devs = json.load(sys.stdin)["devices"]
best = None
for runtime, items in devs.items():
    m = re.search(r"tvOS-(\d+)-(\d+)", runtime)
    if not m: continue
    for d in items:
        if "Apple TV 4K" in d["name"] and "1080p" not in d["name"]:
            key = (int(m.group(1)), int(m.group(2)), d["name"])
            if best is None or key > best[0]: best = (key, d["udid"])
print(best[1] if best else "")')
[ -n "$UDID" ] || { echo "No Apple TV simulator"; xcrun simctl list devices; exit 1; }
echo "Simulator: $UDID"
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
  rm -f "$OUT/$lang"/*.png
  common=(-language $lang -tvHelpSeen YES -dualPage YES)
  shot "$OUT/$lang/01.png" 30 "${common[@]}" -screen reader -page 2 -tvTheme Coloured
  shot "$OUT/$lang/02.png" 35 "${common[@]}" -screen recite -page 50 -tvTheme Coloured
  shot "$OUT/$lang/03.png" 30 "${common[@]}" -screen text -page 1 -tvTheme Coloured
  shot "$OUT/$lang/04.png" 30 "${common[@]}" -screen panel -page 2 -tvTheme Coloured
  shot "$OUT/$lang/05.png" 30 "${common[@]}" -screen reader -page 293 -tvTheme Night
  shot "$OUT/$lang/06.png" 20 -language $lang -tvHelpSeen NO -screen help -tvTheme Coloured
  shot "$OUT/$lang/07.png" 15 -language $lang -tvHelpSeen YES -screen dedication -page 1
done
xcrun simctl terminate "$UDID" $ID 2>/dev/null
