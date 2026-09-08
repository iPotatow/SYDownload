#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Packaging SYDownload.app requires macOS."
  exit 2
fi

CONFIGURATION="${CONFIGURATION:-release}"
APP_VERSION="${APP_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
ADHOC_SIGN="${ADHOC_SIGN:-1}"
BUNDLE_RUNTIME="${BUNDLE_RUNTIME:-1}"

swift build -c "$CONFIGURATION" --product SYDownload
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN="$BIN_DIR/SYDownload"
APP="$ROOT/dist/SYDownload.app"
RESOURCE="$ROOT/Sources/SYDownloadApp/Resources/SYDownloadIcon.png"
RESOURCE_BUNDLE="$BIN_DIR/SYDownload_SYDownloadApp.bundle"

if [[ ! -f "$RESOURCE" ]]; then
  echo "Missing app icon resource: $RESOURCE" >&2
  exit 3
fi
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
  exit 3
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bridge"
cp "$BIN" "$APP/Contents/MacOS/SYDownload"
chmod +x "$APP/Contents/MacOS/SYDownload"
# SwiftPM's generated Bundle.module accessor for an executable resolves the
# resource bundle next to Bundle.main.bundleURL. Keep that location available
# in the manually assembled .app, and also retain the conventional Resources
# copy for direct bundle/resource inspection.
cp -R "$RESOURCE_BUNDLE" "$APP/"
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
cp "$RESOURCE" "$APP/Contents/Resources/SYDownloadIcon.png"
cp "$ROOT/Bridge/engine_bridge.py" "$APP/Contents/Resources/bridge/engine_bridge.py"
cp "$ROOT/Bridge/download_runtime.py" "$APP/Contents/Resources/bridge/download_runtime.py"
printf '%s\n' "$APP_VERSION" > "$APP/Contents/Resources/bundle-version.txt"

if [[ "$BUNDLE_RUNTIME" == "1" ]]; then
  "$ROOT/script/bundle_runtime.sh" "$APP"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>SYDownload</string>
<key>CFBundleIdentifier</key><string>com.sydownload.app</string>
<key>CFBundleName</key><string>SYDownload</string>
<key>CFBundleDisplayName</key><string>SYDownload</string>
<key>CFBundleVersion</key><string>${APP_VERSION}</string>
<key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
<key>CFBundleIconFile</key><string>SYDownloadIcon.png</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

/usr/bin/plutil -lint "$APP/Contents/Info.plist"

if /usr/bin/find "$APP" -type l -print | /usr/bin/grep -q .; then
  echo "Refusing to sign app bundle with symbolic links:"
  /usr/bin/find "$APP" -type l -print
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
  done < <(/usr/bin/find "$APP" -type f -print0)

  /usr/bin/codesign --force --deep --sign - "$APP"
  /usr/bin/codesign --verify --deep --strict "$APP"
fi

printf '%s\n' "$APP"
