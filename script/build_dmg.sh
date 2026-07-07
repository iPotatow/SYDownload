#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 PATH_TO_APP VERSION RELEASE_DIRECTORY" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$1"
VERSION="$2"
RELEASE_DIR="$3"
VOLUME_NAME="SYDownload"
CREATE_DMG="$(command -v create-dmg || true)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sydownload-dmg.XXXXXX")"
DMG_ROOT="$TEMP_ROOT/root"
BACKGROUND_DIR="$DMG_ROOT/.background"
FINAL_DMG="$RELEASE_DIR/SYDownload-$VERSION.dmg"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

test -d "$APP"
if [[ -z "$CREATE_DMG" ]]; then
  echo "create-dmg is required. Install it with: brew install create-dmg" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR" "$DMG_ROOT" "$BACKGROUND_DIR"

ditto "$APP" "$DMG_ROOT/SYDownload.app"
cp "$ROOT_DIR/.github/release-assets/Install.command" \
  "$DMG_ROOT/Install.command"
chmod +x "$DMG_ROOT/Install.command"

swift "$ROOT_DIR/script/create_dmg_background.swift" "$BACKGROUND_DIR/dmg-background.png"

rm -f "$FINAL_DMG"
"$CREATE_DMG" \
  --volname "$VOLUME_NAME" \
  --background "$BACKGROUND_DIR/dmg-background.png" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --text-size 11 \
  --icon-size 84 \
  --icon "SYDownload.app" 140 190 \
  --hide-extension "SYDownload.app" \
  --app-drop-link 400 190 \
  --icon "Install.command" 270 290 \
  --hide-extension "Install.command" \
  --no-internet-enable \
  --format UDZO \
  "$FINAL_DMG" \
  "$DMG_ROOT" >/dev/null

test -s "$FINAL_DMG"
echo "Created $FINAL_DMG"
