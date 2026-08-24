#!/usr/bin/env bash
# Build the release APK and copy it to dist/android/.
#
# Usage:
#   bash tool/build_apk.sh
#   SKIP_BUILD=1 bash tool/build_apk.sh   # only copy an already-built APK
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION_LINE="$(grep '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
MARKETING="${VERSION_LINE%%+*}"
BUILD="${VERSION_LINE##*+}"

SRC_APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
DIST_DIR="$ROOT/dist/android"
DIST_APK="$DIST_DIR/EastmarkHK-Snowball-${MARKETING}-android.apk"

SKIP_BUILD="${SKIP_BUILD:-0}"
DART_DEFINES=()
if [[ -f "$ROOT/dart_defines.json" ]]; then
  DART_DEFINES+=(--dart-define-from-file=dart_defines.json)
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "==> flutter build apk --release"
  flutter build apk --release "${DART_DEFINES[@]}"
fi

if [[ ! -f "$SRC_APK" ]]; then
  echo "error: missing $SRC_APK" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
cp -f "$SRC_APK" "$DIST_APK"
cp -f "$SRC_APK" "$DIST_DIR/EastmarkHK-Snowball-android.apk"

echo
echo "APK ready:"
echo "  $DIST_APK"
echo "  $DIST_DIR/EastmarkHK-Snowball-android.apk"
echo "  version ${MARKETING} (${BUILD})"
ls -lh "$DIST_APK"
