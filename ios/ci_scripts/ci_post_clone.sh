#!/bin/sh
# =============================================================================
# Xcode Cloud — Flutter setup for the iOS / iPad workflow.
#
# Xcode Cloud clones GitHub then runs xcodebuild. It does not have Flutter,
# and ios/Flutter/Generated.xcconfig is not in git. Without this script the
# archive fails before compiling.
#
# Must stay executable IN git:
#   git update-index --chmod=+x ios/ci_scripts/ci_post_clone.sh
# =============================================================================
set -eu
trap 'echo "ERROR: ci_post_clone.sh failed at line $LINENO (exit $?)" >&2' ERR

FLUTTER_VERSION="3.47.2"
FLUTTER_CHANNEL="stable"
FLUTTER_DIR="$HOME/flutter"
BUILD_NUMBER_OFFSET="${BUILD_NUMBER_OFFSET:-0}"

export CI="${CI:-true}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export PUB_ENVIRONMENT="${PUB_ENVIRONMENT:-flutter_bot}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "=== Xcode Cloud: Flutter $FLUTTER_VERSION ($FLUTTER_CHANNEL, iOS) ==="

cd "$CI_PRIMARY_REPOSITORY_PATH"
git config --global --add safe.directory "$CI_PRIMARY_REPOSITORY_PATH" 2>/dev/null || true
git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true
git config --global --add safe.directory '*' 2>/dev/null || true

flutter_ok() {
  [ -x "$FLUTTER_DIR/bin/flutter" ] && \
    "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | grep -q "$FLUTTER_VERSION"
}

if ! flutter_ok; then
  rm -rf "$FLUTTER_DIR"
  if [ "$(uname -m)" = "arm64" ]; then
    ARCHIVE="flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
  else
    ARCHIVE="flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
  fi
  URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/$ARCHIVE"

  echo "--- Downloading $ARCHIVE"
  if curl --retry 5 --retry-delay 5 --connect-timeout 30 -fL -o "$HOME/$ARCHIVE" "$URL"; then
    unzip -q -o "$HOME/$ARCHIVE" -d "$HOME"
    rm -f "$HOME/$ARCHIVE"
  else
    echo "--- Archive missing, clone Flutter tag $FLUTTER_VERSION"
    git clone --branch "$FLUTTER_VERSION" --single-branch \
      https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "ERROR: Flutter SDK missing at $FLUTTER_DIR/bin/flutter" >&2
  exit 1
fi
flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter config --enable-swift-package-manager

echo "--- flutter precache --ios"
flutter precache --ios

echo "--- flutter pub get"
flutter pub get

BUILD_NUMBER=$(( ${CI_BUILD_NUMBER:-1} + BUILD_NUMBER_OFFSET ))
DART_DEFINES=""
if [ -n "${MISTRAL_API_KEY:-}" ]; then
  DART_DEFINES="--dart-define=MISTRAL_API_KEY=${MISTRAL_API_KEY}"
fi

echo "--- flutter build ios --config-only (build number $BUILD_NUMBER)"
# --no-codesign: Xcode Cloud signs the archive.
# shellcheck disable=SC2086
flutter build ios --config-only --release --no-codesign --build-number="$BUILD_NUMBER" $DART_DEFINES

echo "=== Ready (SwiftPM). Xcode Cloud can archive iOS / iPad. ==="
