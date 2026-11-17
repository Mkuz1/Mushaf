#!/bin/zsh
# Generates AppStore/Mushaf.xcodeproj (the Mac App Store build) with XcodeGen, and its icon set from
# Assets/AppIcon.png. MUSHAF_BUILD: the build number (default 1).
set -euo pipefail
cd "$(dirname "$0")"
export MUSHAF_VERSION="$(tr -d '[:space:]' < ../VERSION)"
export MUSHAF_BUILD="${MUSHAF_BUILD:-1}"

set_dir=AppIcon.xcassets/AppIcon.appiconset
rm -rf AppIcon.xcassets
mkdir -p "$set_dir"
echo '{"info":{"version":1,"author":"xcode"}}' > AppIcon.xcassets/Contents.json
images=""
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale)); name="icon_${size}x${size}@${scale}x.png"
    sips -z $px $px ../Assets/AppIcon.png --out "$set_dir/$name" >/dev/null
    images="$images{\"idiom\":\"mac\",\"size\":\"${size}x${size}\",\"scale\":\"${scale}x\",\"filename\":\"$name\"},"
  done
done
echo "{\"images\":[${images%,}],\"info\":{\"version\":1,\"author\":\"xcode\"}}" > "$set_dir/Contents.json"

xcodegen generate --spec project.yml
echo "Mushaf.xcodeproj: $MUSHAF_VERSION ($MUSHAF_BUILD)"
