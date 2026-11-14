#!/usr/bin/env bash
# Builds a release of Reclaim: a universal Release build, signed ad hoc, as a disk image and a zip, each with a
# SHA-256 checksum.
#
#   scripts/release.sh            build into dist/
#   scripts/release.sh --publish  also create the GitHub release v<version> with notes from CHANGELOG.md
#   scripts/release.sh --upload   also replace the files of the existing release v<version>
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

# The disk image: the app next to a link to Applications, to drag it onto.
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/Reclaim.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Reclaim $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 \
  -ov -quiet dist/Reclaim.dmg
rm -rf "$STAGE"
codesign --force --sign - dist/Reclaim.dmg
hdiutil verify -quiet dist/Reclaim.dmg

(cd dist && shasum -a 256 Reclaim.dmg > Reclaim.dmg.sha256 && shasum -a 256 Reclaim.zip > Reclaim.zip.sha256)

# Release notes: this version's section of the changelog.
awk -v v="$VERSION" '$0 ~ "^## \\[?"v"\\]?" {on=1; next} on && /^## / {exit} on' CHANGELOG.md > dist/notes.md
echo "Built dist/Reclaim.dmg ($(du -h dist/Reclaim.dmg | cut -f1)) and dist/Reclaim.zip ($(du -h dist/Reclaim.zip | cut -f1))"
cat dist/*.sha256

# --publish creates the release; --upload replaces the files of an existing one.
ASSETS=(dist/Reclaim.dmg dist/Reclaim.dmg.sha256 dist/Reclaim.zip dist/Reclaim.zip.sha256)
case "${1:-}" in
  --publish) gh release create "$TAG" "${ASSETS[@]}" --title "Reclaim $VERSION" --notes-file dist/notes.md ;;
  --upload) gh release upload "$TAG" "${ASSETS[@]}" --clobber ;;
esac
