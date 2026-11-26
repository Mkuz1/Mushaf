#!/bin/zsh
# Runs Mushaf (a Debug simulator build: its screenshot hook, lib/debug/screenshot_hook.dart) in Xcode's iPhone Duo
# simulator and captures every display, for each screen and language, into $2. Also prints what the simulator
# offers (displays, fold controls), for the workflow log.
#   duo-capture.sh <Runner.app> <out dir> [languages]
set -uo pipefail
APP="$1"; OUT="$2"; LANGS="${3:-en fr ar}"
ID=com.kousa.mushaf
mkdir -p "$OUT"
TYPE=$(xcrun simctl list devicetypes | grep -i "duo" | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9.-]+' | tail -1)
echo "Device type: ${TYPE:-none}"
[ -n "$TYPE" ] || { xcrun simctl list devicetypes; exit 1; }
# The newest iOS runtime that accepts the iPhone Duo (not every installed one does).
UDID=""
for RUNTIME in $(xcrun simctl list runtimes available | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | sort -t- -k2,2n -k3,3n | tail -r); do
  UDID=$(xcrun simctl create "iPhone Duo" "$TYPE" "$RUNTIME" 2>/dev/null) && { echo "Runtime: $RUNTIME"; break; }
done
if [ -z "$UDID" ]; then
  echo "No installed iOS runtime accepts $TYPE"; xcrun simctl list runtimes; exit 1
fi
xcrun simctl boot "$UDID" || exit 1
xcrun simctl bootstatus "$UDID" -b || exit 1
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null
sleep 25

echo "== Displays (simctl io enumerate)"
xcrun simctl io "$UDID" enumerate 2>&1 | tee "$OUT/displays.txt"
echo "== simctl io help"
xcrun simctl help io 2>&1 | tee "$OUT/io-help.txt"
echo "== screenConfig"
for a in "" help list --help; do echo "--- screenConfig $a"; xcrun simctl io "$UDID" screenConfig $a 2>&1 | head -60; done | tee "$OUT/screenconfig.txt"
echo "== Device type profile"
BUNDLE=$(xcrun simctl list devicetypes -j | python3 -c "
import json, sys
d = json.load(sys.stdin)['devicetypes']
print(next((t['bundlePath'] for t in d if t['identifier'] == sys.argv[1]), ''))" "$TYPE")
plutil -p "$BUNDLE/Contents/Resources/profile.plist" 2>&1 | head -150 | tee "$OUT/profile.txt"

xcrun simctl install "$UDID" "$APP" || exit 1
# The phone's own screens (display class 0): the inner and the outer one, not the external-display ports.
DISPLAYS=($(awk '/UUID:/{u=$2} /Display class: 0/{print u}' "$OUT/displays.txt" | sort -u))
echo "Display ids: ${DISPLAYS[*]:-none}"

shot() {  # shot <name> <screen> <page> <lang>
  xcrun simctl terminate "$UDID" $ID 2>/dev/null
  # The screenshot hook reads this file (lib/debug/screenshot_hook.dart).
  local data; data=$(xcrun simctl get_app_container "$UDID" $ID data)
  mkdir -p "$data/Documents"
  printf 'MUSHAF_SHOT=%s\nMUSHAF_PAGE=%s\nMUSHAF_LANG=%s\n' "$2" "$3" "$4" > "$data/Documents/screenshot.txt"
  xcrun simctl launch "$UDID" $ID >/dev/null || return
  sleep 35
  xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null 2>&1 && echo "$1.png"
  local i=0
  for d in "${DISPLAYS[@]}"; do
    i=$((i + 1))
    xcrun simctl io "$UDID" screenshot --display="$d" "$OUT/$1-display$i.png" >/dev/null 2>&1 && echo "$1-display$i.png"
  done
}

for lang in ${=LANGS}; do
  shot "$lang-1-reader" reader 2 $lang
  shot "$lang-2-recite" recite 50 $lang
  shot "$lang-3-text" text 1 $lang
  shot "$lang-4-panel" panel 2 $lang
  shot "$lang-5-opening" dedication 1 $lang
done
xcrun simctl terminate "$UDID" $ID 2>/dev/null
echo "== Sizes"
for f in "$OUT"/*.png; do echo "$(basename "$f"): $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"; done
