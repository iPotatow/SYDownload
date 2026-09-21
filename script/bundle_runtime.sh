#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/SYDownload.app}"
RESOURCES="$APP/Contents/Resources"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

XHS_REVISION="${XHS_REVISION:-47840a1bee8438324ff10753c4291148c46071c8}"
DOUK_REVISION="${DOUK_REVISION:-207e2184e1004f4f5bf87fb69231f3bb5731adbb}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Bundling the macOS Python runtime requires macOS."
  exit 2
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to bundle Python. Install it from https://docs.astral.sh/uv/"
  exit 2
fi

if [[ ! -d "$APP/Contents" ]]; then
  echo "App bundle not found: $APP"
  exit 2
fi

WORK="$ROOT/.build/sydownload-bundle"
SOURCES="$WORK/sources"
PYTHON_BUILD_ROOT="$WORK/python-managed"
PYTHON_ROOT="$RESOURCES/python"
ENGINES_ROOT="$RESOURCES/engines"
rm -rf "$WORK" "$PYTHON_ROOT" "$ENGINES_ROOT"
mkdir -p "$SOURCES" "$PYTHON_BUILD_ROOT" "$PYTHON_ROOT" "$ENGINES_ROOT"

fetch_revision() {
  local url="$1"
  local revision="$2"
  local destination="$3"

  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch -q --depth 1 origin "$revision"
  git -C "$destination" checkout -q --detach FETCH_HEAD
}

echo "Fetching pinned downloader engines..."
fetch_revision "https://github.com/JoeanAmier/XHS-Downloader.git" "$XHS_REVISION" "$SOURCES/XHS-Downloader"
fetch_revision "https://github.com/JoeanAmier/TikTokDownloader.git" "$DOUK_REVISION" "$SOURCES/TikTokDownloader"

# Dereference source-tree symlinks so the finished .app has no link whose
# destination macOS code signing could consider outside the bundle.
/usr/bin/rsync -aL --exclude='.git/' --exclude='__pycache__/' --exclude='*.pyc' \
  "$SOURCES/XHS-Downloader/" "$ENGINES_ROOT/XHS-Downloader/"
/usr/bin/rsync -aL --exclude='.git/' --exclude='__pycache__/' --exclude='*.pyc' \
  "$SOURCES/TikTokDownloader/" "$ENGINES_ROOT/TikTokDownloader/"

# Keep engine bookkeeping and optional data exports inside the staged engine data
# area. The user-selected download directory must contain only downloaded media.
echo "Applying SYDownload engine data-path adapters..."
/usr/bin/python3 - \
  "$ENGINES_ROOT/XHS-Downloader/source/module/recorder.py" \
  "$ENGINES_ROOT/TikTokDownloader/src/storage/manager.py" \
  "$ENGINES_ROOT/XHS-Downloader/source/application/download.py" \
  "$ENGINES_ROOT/XHS-Downloader/source/application/app.py" \
  "$ENGINES_ROOT/TikTokDownloader/src/downloader/download.py" <<'PY'
from pathlib import Path
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


xhs_path = Path(sys.argv[1])
xhs = xhs_path.read_text(encoding="utf-8")
xhs = replace_once(
    xhs,
    "self.file = manager.folder.joinpath(self.name)",
    "self.file = manager.root.joinpath(self.name)",
    "XHS ExploreData path",
)
xhs_path.write_text(xhs, encoding="utf-8")

douk_path = Path(sys.argv[2])
douk = douk_path.read_text(encoding="utf-8")
douk = replace_once(
    douk,
    "from typing import TYPE_CHECKING\n\nfrom .csv import CSVLogger",
    "from typing import TYPE_CHECKING\n\nfrom ..custom import VOLUME\nfrom .csv import CSVLogger",
    "DouK VOLUME import",
)
douk = replace_once(
    douk,
    "root = parameter.root.joinpath(",
    "root = VOLUME.joinpath(",
    "DouK data root",
)
douk = replace_once(
    douk,
    "self.compatible(\n            parameter.root,\n            root,\n            name,\n        )",
    "self.compatible(\n            VOLUME,\n            root,\n            name,\n        )",
    "DouK data migration root",
)
douk_path.write_text(douk, encoding="utf-8")

# SYDownload exposes an explicit "overwrite existing files" preference. The
# upstream engines normally skip when either an ID record or the target file
# already exists, so teach the bundled copies to honor the per-task environment
# override without changing upstream defaults.
xhs_download_path = Path(sys.argv[3])
xhs_download = xhs_download_path.read_text(encoding="utf-8")
xhs_download = replace_once(
    xhs_download,
    "from pathlib import Path\n",
    "from os import getenv\nfrom pathlib import Path\n",
    "XHS overwrite getenv import",
)
xhs_download = replace_once(
    xhs_download,
    "    def __check_exists_glob(\n        self,\n        path: Path,\n        name: str,\n    ) -> bool:\n        if any(path.glob(name)):",
    "    def __check_exists_glob(\n        self,\n        path: Path,\n        name: str,\n    ) -> bool:\n        if getenv(\"SYDOWNLOAD_OVERWRITE_EXISTING\") == \"1\":\n            return False\n        if any(path.glob(name)):",
    "XHS overwrite glob",
)
xhs_download = replace_once(
    xhs_download,
    "    def __check_exists_path(\n        self,\n        path: Path,\n        name: str,\n    ) -> bool:\n        if path.joinpath(name).exists():",
    "    def __check_exists_path(\n        self,\n        path: Path,\n        name: str,\n    ) -> bool:\n        if getenv(\"SYDOWNLOAD_OVERWRITE_EXISTING\") == \"1\":\n            return False\n        if path.joinpath(name).exists():",
    "XHS overwrite path",
)
xhs_download_path.write_text(xhs_download, encoding="utf-8")

xhs_app_path = Path(sys.argv[4])
xhs_app = xhs_app_path.read_text(encoding="utf-8")
xhs_app = replace_once(
    xhs_app,
    "from datetime import datetime\n",
    "from datetime import datetime\nfrom os import getenv\n",
    "XHS app getenv import",
)
xhs_app = replace_once(
    xhs_app,
    "    async def has_download_record(self, id_: str) -> bool:\n        return bool(await self.id_recorder.select(id_))",
    "    async def has_download_record(self, id_: str) -> bool:\n        if getenv(\"SYDOWNLOAD_OVERWRITE_EXISTING\") == \"1\":\n            return False\n        return bool(await self.id_recorder.select(id_))",
    "XHS overwrite download record",
)
xhs_app_path.write_text(xhs_app, encoding="utf-8")

douk_download_path = Path(sys.argv[5])
douk_download = douk_download_path.read_text(encoding="utf-8")
douk_download = replace_once(
    douk_download,
    "from datetime import datetime\n",
    "from datetime import datetime\nfrom os import getenv\n",
    "DouK overwrite getenv import",
)
douk_download = replace_once(
    douk_download,
    "    async def is_downloaded(self, id_: str) -> bool:\n        return await self.recorder.has_id(id_)",
    "    async def is_downloaded(self, id_: str) -> bool:\n        if getenv(\"SYDOWNLOAD_OVERWRITE_EXISTING\") == \"1\":\n            return False\n        return await self.recorder.has_id(id_)",
    "DouK overwrite record",
)
douk_download = replace_once(
    douk_download,
    "    @staticmethod\n    def is_exists(path: Path) -> bool:\n        return path.exists()",
    "    @staticmethod\n    def is_exists(path: Path) -> bool:\n        if getenv(\"SYDOWNLOAD_OVERWRITE_EXISTING\") == \"1\":\n            return False\n        return path.exists()",
    "DouK overwrite path",
)
douk_download_path.write_text(douk_download, encoding="utf-8")
PY

echo "Installing portable Python $PYTHON_VERSION into build staging..."
UV_PYTHON_INSTALL_DIR="$PYTHON_BUILD_ROOT" \
  uv python install --managed-python --no-bin "$PYTHON_VERSION"
PYTHON_BIN="$(UV_PYTHON_INSTALL_DIR="$PYTHON_BUILD_ROOT" uv python find --managed-python "$PYTHON_VERSION")"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Staged Python executable not found after installation."
  exit 3
fi

PYTHON_INSTALL_DIR="$(dirname "$(dirname "$PYTHON_BIN")")"
PYTHON_INSTALL_NAME="$(basename "$PYTHON_INSTALL_DIR")"
PYTHON_EXE="$(basename "$PYTHON_BIN")"

REQUIREMENTS="$WORK/requirements.txt"
"$PYTHON_BIN" - "$SOURCES/XHS-Downloader/requirements.txt" "$SOURCES/TikTokDownloader/requirements.txt" > "$REQUIREMENTS" <<'PY'
from pathlib import Path
import sys

# Both engines publish exact direct-dependency pins for their release commits.
# Merge those instead of resolving the broader >= ranges from pyproject.toml so
# a fixed engine revision does not silently change its direct dependency set.
seen = set()
for raw in sys.argv[1:]:
    for line in Path(raw).read_text(encoding="utf-8").splitlines():
        requirement = line.strip()
        if not requirement or requirement.startswith("#"):
            continue
        if requirement not in seen:
            seen.add(requirement)
            print(requirement)

# XHS-Downloader keeps its browser-cookie integration source but no longer
# declares rookiepy because the upstream CLI entry point is disabled. SYDownload
# calls the integration directly, so pin it explicitly.
print("rookiepy==0.5.6")
PY

echo "Installing Python dependencies into staged runtime..."
uv pip install --python "$PYTHON_BIN" --system --break-system-packages -r "$REQUIREMENTS"

export PYTHONDONTWRITEBYTECODE=1
export PYTHONNOUSERSITE=1

"$PYTHON_BIN" - <<'PY'
import aiofiles
import aiosqlite
import curl_cffi
import fastapi
import javascript
import lxml
import openpyxl
import pydantic
import pyperclip
import rookiepy
import rich
import uvicorn
import webview
print("Staged dependency smoke test passed")
PY

# python-build-standalone includes symlinks. A link valid in its build staging
# location can be rejected after the tree is moved under an app bundle. Copy
# the complete managed runtime with -L so every link becomes real content.
mkdir -p "$PYTHON_ROOT/$PYTHON_INSTALL_NAME" "$PYTHON_ROOT/bin"
/usr/bin/rsync -aL "$PYTHON_INSTALL_DIR/" "$PYTHON_ROOT/$PYTHON_INSTALL_NAME/"

cat > "$PYTHON_ROOT/bin/python3" <<SH
#!/bin/sh
SCRIPT_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
exec "\$SCRIPT_DIR/../$PYTHON_INSTALL_NAME/bin/$PYTHON_EXE" "\$@"
SH
chmod +x "$PYTHON_ROOT/bin/python3"

# Validate the copied, relocatable runtime rather than only the staging copy.
"$PYTHON_ROOT/bin/python3" - <<'PY'
import curl_cffi
import javascript
import lxml
import pydantic
import rookiepy
import webview
print("Bundled relocated runtime smoke test passed")
PY

# The finished app deliberately contains no symlinks. This makes bundle
# integrity deterministic for both ad-hoc signing now and Developer ID later.
if /usr/bin/find "$RESOURCES" -type l -print | /usr/bin/grep -q .; then
  echo "Unexpected symbolic links remain in app resources:"
  /usr/bin/find "$RESOURCES" -type l -print
  exit 4
fi

cat > "$RESOURCES/engine-manifest.json" <<JSON
{
  "python": "$PYTHON_VERSION",
  "python_install": "$PYTHON_INSTALL_NAME",
  "engines": {
    "XHS-Downloader": "$XHS_REVISION",
    "TikTokDownloader": "$DOUK_REVISION"
  }
}
JSON

printf '%s\n' "$PYTHON_ROOT/bin/python3"
