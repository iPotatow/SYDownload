#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sydownload-state.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SDK="${SWIFT_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
swiftc -sdk "$SDK" -module-cache-path "$TEST_DIR/module-cache" \
  -emit-library -emit-module -module-name SYDownloadCore \
  "$ROOT"/Sources/SYDownloadCore/*.swift -o "$TEST_DIR/libSYDownloadCore.dylib" \
  -emit-module-path "$TEST_DIR/SYDownloadCore.swiftmodule"
swiftc -sdk "$SDK" -module-cache-path "$TEST_DIR/module-cache" \
  -I "$TEST_DIR" -L "$TEST_DIR" -lSYDownloadCore -Xlinker -rpath -Xlinker "$TEST_DIR" \
  "$ROOT"/Sources/SYDownloadApp/Models/*.swift \
  "$ROOT/Sources/SYDownloadApp/Services/AsyncSemaphore.swift" \
  "$ROOT/Sources/SYDownloadApp/Services/BridgeClient.swift" \
  "$ROOT/Sources/SYDownloadApp/Services/ExifProcessingService.swift" \
  "$ROOT/Sources/SYDownloadApp/Services/PhotoLibraryService.swift" \
  "$ROOT/script/test_ui_state.swift" -o "$TEST_DIR/state-tests"
"$TEST_DIR/state-tests"
