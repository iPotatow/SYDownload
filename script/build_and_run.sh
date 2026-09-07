#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script stages and launches the macOS .app and therefore requires macOS."
  echo "On non-macOS systems run: swift test && python3 -m unittest discover Bridge/tests"
  exit 2
fi

pkill -x XDownloader 2>/dev/null || true

CONFIGURATION=debug APP_VERSION=0.1.0 "$ROOT/script/package_app.sh" >/dev/null
APP="$ROOT/dist/XDownloader.app"

export XDOWNLOADER_XHS_ROOT="${XDOWNLOADER_XHS_ROOT:-$ROOT/Engines/XHS-Downloader}"
export XDOWNLOADER_DOUK_ROOT="${XDOWNLOADER_DOUK_ROOT:-$ROOT/Engines/TikTokDownloader}"
/usr/bin/open -n "$APP"
echo "Launched $APP"
