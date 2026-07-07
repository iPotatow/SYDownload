#!/bin/zsh

set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(find "$HERE" -maxdepth 1 -type d -name "*.app" -print -quit)"

if [[ -z "$APP" ]]; then
    echo "App not found."
    read -r "?Press Return to exit…"
    exit 1
fi

NAME="$(basename "$APP")"
TARGET="/Applications/$NAME"

echo "Installing $NAME…"

rm -rf "$TARGET"
/usr/bin/ditto "$APP" "$TARGET"
/usr/bin/xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
/usr/bin/open "$TARGET"

echo "Done."
