#!/bin/sh
# Installs or updates Reclaim from the latest GitHub release:
#
#   curl -fsSL https://reclaim.mostofa.me/install.sh | sh
#
# Files downloaded with curl are not quarantined, so macOS opens Reclaim without the "could not verify" warning
# that a browser download gets. The disk image is checked against its published SHA-256 checksum first.
set -eu

URL="https://github.com/kstmostofa/reclaim/releases/latest/download/Reclaim.dmg"
DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"

TMP=$(mktemp -d)
cleanup() {
  hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Reclaim…"
curl -fsSL "$URL" -o "$TMP/Reclaim.dmg"
curl -fsSL "$URL.sha256" -o "$TMP/Reclaim.dmg.sha256"
(cd "$TMP" && shasum -a 256 -c -s Reclaim.dmg.sha256) || { echo "The download does not match its checksum." >&2; exit 1; }

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$TMP/mnt" "$TMP/Reclaim.dmg"

if pgrep -xq Reclaim; then
  echo "Quitting Reclaim…"
  osascript -e 'quit app "Reclaim"' >/dev/null 2>&1 || true
  sleep 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/Reclaim.app"
ditto "$TMP/mnt/Reclaim.app" "$DEST/Reclaim.app"

echo "Installed Reclaim $(defaults read "$DEST/Reclaim.app/Contents/Info" CFBundleShortVersionString) in $DEST."
open "$DEST/Reclaim.app"
