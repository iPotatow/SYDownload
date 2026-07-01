#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Packaging XDownloader.app requires macOS."
  exit 2
fi

CONFIGURATION="${CONFIGURATION:-release}"
APP_VERSION="${APP_VERSION:-0.2.0}"
ADHOC_SIGN="${ADHOC_SIGN:-1}"
BUNDLE_RUNTIME="${BUNDLE_RUNTIME:-1}"

swift build -c "$CONFIGURATION" --product XDownloader
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN="$BIN_DIR/XDownloader"
APP="$ROOT/dist/XDownloader.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bridge"
cp "$BIN" "$APP/Contents/MacOS/XDownloader"
chmod +x "$APP/Contents/MacOS/XDownloader"
cp "$ROOT/Bridge/engine_bridge.py" "$APP/Contents/Resources/bridge/engine_bridge.py"
printf '%s\n' "$APP_VERSION" > "$APP/Contents/Resources/bundle-version.txt"

if [[ "$BUNDLE_RUNTIME" == "1" ]]; then
  "$ROOT/script/bundle_runtime.sh" "$APP"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>XDownloader</string>
<key>CFBundleIdentifier</key><string>com.xdownloader.spike</string>
<key>CFBundleName</key><string>XDownloader</string>
<key>CFBundleDisplayName</key><string>XDownloader</string>
<key>CFBundleVersion</key><string>${APP_VERSION}</string>
<key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

/usr/bin/plutil -lint "$APP/Contents/Info.plist"

if /usr/bin/find "$APP/Contents" -type l -print | /usr/bin/grep -q .; then
  echo "Refusing to sign app bundle with symbolic links:"
  /usr/bin/find "$APP/Contents" -type l -print
  exit 4
fi

if [[ "$ADHOC_SIGN" == "1" ]]; then
  # Apple Silicon requires embedded Mach-O code to carry a signature. Sign the
  # portable Python interpreter, native wheels and helper binaries before the
  # outer app bundle.
  while IFS= read -r -d '' candidate; do
    if [[ -x "$candidate" || "$candidate" == *.dylib || "$candidate" == *.so ]]; then
      if /usr/bin/file -b "$candidate" | /usr/bin/grep -q 'Mach-O'; then
        /usr/bin/codesign --force --sign - "$candidate"
      fi
    fi
  done < <(/usr/bin/find "$APP/Contents" -type f -print0)

  /usr/bin/codesign --force --deep --sign - "$APP"
  /usr/bin/codesign --verify --deep --strict "$APP"
fi

printf '%s\n' "$APP"
