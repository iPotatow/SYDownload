#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/Engines"

XHS_REVISION="${XHS_REVISION:-cc7c78088afc09082f54ea6263a9fd07c2fa510f}"
DOUK_REVISION="${DOUK_REVISION:-43e1abc4ab401b31560423450d01648e83c9b48a}"

fetch_revision() {
  local url="$1"
  local revision="$2"
  local destination="$3"

  if [[ -d "$destination/.git" ]]; then
    git -C "$destination" fetch -q --depth 1 origin "$revision"
    git -C "$destination" checkout -q --detach FETCH_HEAD
    return
  fi

  rm -rf "$destination"
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch -q --depth 1 origin "$revision"
  git -C "$destination" checkout -q --detach FETCH_HEAD
}

fetch_revision "https://github.com/JoeanAmier/XHS-Downloader.git" "$XHS_REVISION" "$ROOT/Engines/XHS-Downloader"
fetch_revision "https://github.com/JoeanAmier/TikTokDownloader.git" "$DOUK_REVISION" "$ROOT/Engines/TikTokDownloader"

echo "Pinned engines ready under $ROOT/Engines"
