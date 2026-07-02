#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script stages and launches the macOS .app and therefore requires macOS."
  echo "On non-macOS systems run: swift test && python3 -m unittest discover Bridge/tests"
  exit 2
fi

pkill -x SYDownload 2>/dev/null || true

# Dev runs remain fast and reuse local Engines + system Python. Set
# BUNDLE_RUNTIME=1 to exercise the fully self-contained bundle locally.
CONFIGURATION=debug APP_VERSION=0.2.0 BUNDLE_RUNTIME="${BUNDLE_RUNTIME:-0}" \
  "$ROOT/script/package_app.sh" >/dev/null
APP="$ROOT/dist/SYDownload.app"

export SYDOWNLOAD_XHS_ROOT="${SYDOWNLOAD_XHS_ROOT:-$ROOT/Engines/XHS-Downloader}"
export SYDOWNLOAD_DOUK_ROOT="${SYDOWNLOAD_DOUK_ROOT:-$ROOT/Engines/TikTokDownloader}"
/usr/bin/open -n "$APP"
echo "Launched $APP"
