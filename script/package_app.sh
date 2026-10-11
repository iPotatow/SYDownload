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
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/iPotatow/SYDownload/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$(tr -d '[:space:]' < "$ROOT/sparkle-public-key.txt")}"

SWIFT_OPTIONS=()
if [[ -n "${SWIFT_SDK:-}" ]]; then
  SWIFT_OPTIONS+=(--sdk "$SWIFT_SDK")
fi
swift build "${SWIFT_OPTIONS[@]}" -c "$CONFIGURATION" --product SYDownload
BIN_DIR="$(swift build "${SWIFT_OPTIONS[@]}" -c "$CONFIGURATION" --show-bin-path)"
BIN="$BIN_DIR/SYDownload"
APP="$ROOT/dist/SYDownload.app"
RESOURCE_DIR="$ROOT/Sources/SYDownloadApp/Resources"

for resource in SYDownloadIcon.png XiaohongshuPlatformIcon.jpg DouyinPlatformIcon.jpg; do
  if [[ ! -f "$RESOURCE_DIR/$resource" ]]; then
    echo "Missing app resource: $RESOURCE_DIR/$resource" >&2
    exit 3
  fi
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bridge"
cp "$BIN" "$APP/Contents/MacOS/SYDownload"
chmod +x "$APP/Contents/MacOS/SYDownload"
# SwiftPM links the binary framework but does not embed it in our custom bundle.
SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" -type d -path '*/macos-arm64_x86_64/Sparkle.framework' -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework missing from SwiftPM artifacts" >&2
  exit 3
fi
mkdir -p "$APP/Contents/Frameworks"
/usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$RESOURCE_DIR/SYDownloadIcon.png" "$APP/Contents/Resources/SYDownloadIcon.png"
cp "$RESOURCE_DIR/XiaohongshuPlatformIcon.jpg" "$APP/Contents/Resources/XiaohongshuPlatformIcon.jpg"
cp "$RESOURCE_DIR/DouyinPlatformIcon.jpg" "$APP/Contents/Resources/DouyinPlatformIcon.jpg"
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
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

# Use plist APIs for user-provided values rather than interpolating XML.
/usr/bin/plutil -insert SUFeedURL -string "$SPARKLE_FEED_URL" "$APP/Contents/Info.plist"
/usr/bin/plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$APP/Contents/Info.plist"
/usr/bin/plutil -insert SUEnableAutomaticChecks -bool YES "$APP/Contents/Info.plist"
/usr/bin/plutil -insert SUScheduledCheckInterval -integer 86400 "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"

# Framework version symlinks are required. Reject broken/escaping symlinks,
# rather than banning Sparkle's valid internal links.
python3 "$ROOT/script/verify_bundle_links.py" "$APP"

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
