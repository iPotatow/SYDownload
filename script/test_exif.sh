#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sydownload-exif.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SDK="${SWIFT_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
swiftc -sdk "$SDK" -module-cache-path "$TEST_DIR/module-cache" \
  "$ROOT/Sources/SYDownloadApp/Models/ExifProcessingTypes.swift" \
  "$ROOT/Sources/SYDownloadApp/Services/ExifProcessingService.swift" \
  "$ROOT/script/test_exif.swift" -o "$TEST_DIR/exif-tests"
"$TEST_DIR/exif-tests"
