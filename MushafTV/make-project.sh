#!/bin/zsh
# Generates MushafTV.xcodeproj (Apple TV) with XcodeGen, and its asset catalog from the Mac icon.
# MUSHAF_BUILD: the build number (default 1). The version is the Mac app's (MushafMac/VERSION).
set -euo pipefail
cd "$(dirname "$0")"
export MUSHAF_VERSION="$(tr -d '[:space:]' < ../MushafMac/VERSION)"
export MUSHAF_BUILD="${MUSHAF_BUILD:-1}"
swiftc -O make-assets.swift -o "${TMPDIR:-/tmp}/make-tv-assets"
"${TMPDIR:-/tmp}/make-tv-assets" ../MushafMac/Assets/AppIcon.png Assets.xcassets
xcodegen generate --spec project.yml
echo "MushafTV.xcodeproj: $MUSHAF_VERSION ($MUSHAF_BUILD)"
