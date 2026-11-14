#!/usr/bin/env bash
# Builds a release of Reclaim: a universal Release build, signed ad hoc, zipped with a SHA-256 checksum.
#
#   scripts/release.sh            build into dist/
#   scripts/release.sh --publish  also create the GitHub release v<version> with notes from CHANGELOG.md
#
# The version is MARKETING_VERSION in project.yml. Without a paid Developer ID the app is signed ad hoc and not
# notarized, so people open it the first time through System Settings › Privacy & Security › Open Anyway.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)
TAG="v$VERSION"
DERIVED=build/release
APP="$DERIVED/Build/Products/Release/Reclaim.app"
HELPER="$APP/Contents/MacOS/io.github.kstmostofa.reclaim.helper"

echo "Building Reclaim $VERSION"
xcodegen generate --quiet
xcodebuild -project Reclaim.xcodeproj -scheme Reclaim -configuration Release -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build -quiet

# Sign inside out: the helper, then the app, both with the hardened runtime.
codesign --force --sign - --options runtime --identifier io.github.kstmostofa.reclaim.helper "$HELPER"
codesign --force --sign - --options runtime "$APP"
codesign --verify --strict --verbose=1 "$APP"
lipo -archs "$APP/Contents/MacOS/Reclaim" | grep -q "x86_64 arm64\|arm64 x86_64" || { echo "Not a universal binary"; exit 1; }

rm -rf dist && mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Reclaim.zip
(cd dist && shasum -a 256 Reclaim.zip > Reclaim.zip.sha256)

# Release notes: this version's section of the changelog.
awk -v v="$VERSION" '$0 ~ "^## \\[?"v"\\]?" {on=1; next} on && /^## / {exit} on' CHANGELOG.md > dist/notes.md
echo "Built dist/Reclaim.zip ($(du -h dist/Reclaim.zip | cut -f1)), $(cat dist/Reclaim.zip.sha256)"

if [[ "${1:-}" == "--publish" ]]; then
  gh release create "$TAG" dist/Reclaim.zip dist/Reclaim.zip.sha256 --title "Reclaim $VERSION" --notes-file dist/notes.md
fi
