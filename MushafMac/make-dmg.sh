#!/bin/zsh
# Builds build/Mushaf.dmg: the app and an Applications shortcut. The mushaf pages are NOT included;
# the app offers to download them from the GitHub release on first run, or reads them online.
set -euo pipefail
cd "$(dirname "$0")"
./make-app.sh
STAGE="$(mktemp -d)/Mushaf"
mkdir -p "$STAGE"
cp -R build/Mushaf.app "$STAGE/Mushaf.app"
ln -s /Applications "$STAGE/Applications"
rm -f build/Mushaf.dmg
hdiutil create -volname "Mushaf" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov build/Mushaf.dmg >/dev/null
echo "Built $PWD/build/Mushaf.dmg ($(du -h build/Mushaf.dmg | cut -f1))"
