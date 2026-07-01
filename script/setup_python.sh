#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"

for engine in XHS-Downloader TikTokDownloader; do
  dir="$ROOT/Engines/$engine"
  [[ -f "$dir/pyproject.toml" ]] || { echo "Missing $dir; run script/fetch_engines.sh first"; exit 1; }
  if command -v uv >/dev/null 2>&1; then
    (cd "$dir" && uv sync --python 3.12)
  else
    "$PYTHON" -m venv "$dir/.venv"
    "$dir/.venv/bin/pip" install -r "$dir/requirements.txt"
  fi
done
