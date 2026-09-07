#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/Engines"

if [[ ! -d "$ROOT/Engines/XHS-Downloader/.git" ]]; then
  git clone --depth 1 https://github.com/JoeanAmier/XHS-Downloader.git "$ROOT/Engines/XHS-Downloader"
fi
if [[ ! -d "$ROOT/Engines/TikTokDownloader/.git" ]]; then
  git clone --depth 1 https://github.com/JoeanAmier/TikTokDownloader.git "$ROOT/Engines/TikTokDownloader"
fi

echo "Engines ready under $ROOT/Engines"
