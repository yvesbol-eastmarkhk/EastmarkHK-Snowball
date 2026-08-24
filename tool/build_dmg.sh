#!/usr/bin/env bash
# Build EastmarkHK Snowball macOS .app → styled .dmg (Developer ID + notarize).
#
# Usage:
#   bash tool/build_dmg.sh
#   SKIP_BUILD=1 bash tool/build_dmg.sh
#   NOTARIZE=0 bash tool/build_dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_DISPLAY_NAME="EastmarkHK Snowball"
APP_FILE_NAME="${APP_DISPLAY_NAME}.app"
VERSION_LINE="$(grep '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
MARKETING="${VERSION_LINE%%+*}"
BUILD="${VERSION_LINE##*+}"
DMG_BASENAME="EastmarkHK-Snowball-${MARKETING}-macos"
DIST_DIR="$ROOT/dist/macos"
BUILD_DIR="$ROOT/build/dmg"
STAGING="$BUILD_DIR/staging"
DMG_FINAL="$DIST_DIR/${DMG_BASENAME}.dmg"
TMP_DMG="$BUILD_DIR/tmp.dmg"
ASSETS="$ROOT/installer/macos"
BG_OUT="$ASSETS/dmg_background.png"
LOGO="$ROOT/assets/logo.png"
APPICON_SRC="$ROOT/assets/logo_full.png"
SKIP_BUILD="${SKIP_BUILD:-0}"
NOTARIZE="${NOTARIZE:-1}"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-EastmarkHK}"

DEVELOPER_ID_SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-}"
if [[ -z "$DEVELOPER_ID_SIGNING_IDENTITY" ]]; then
  DEVELOPER_ID_SIGNING_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
      | head -1
  )"
fi
if [[ -z "$DEVELOPER_ID_SIGNING_IDENTITY" ]]; then
  echo "error: no Developer ID Application identity in Keychain" >&2
  exit 1
fi

if [[ ! -f "$LOGO" ]]; then
  LOGO="$ROOT/assets/logo.png"
  APPICON_SRC="$LOGO"
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "==> Flutter build (macos release)…"
  flutter pub get
  flutter build macos --release
else
  echo "==> SKIP_BUILD=1 — reusing existing Release .app"
fi

APP_SRC="$ROOT/build/macos/Build/Products/Release/${APP_FILE_NAME}"
if [[ ! -d "$APP_SRC" ]]; then
  ALT="$(find "$ROOT/build/macos/Build/Products/Release" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
  [[ -n "$ALT" && -d "$ALT" ]] && APP_SRC="$ALT"
fi
if [[ ! -d "$APP_SRC" ]]; then
  echo "error: Release .app not found" >&2
  ls -la "$ROOT/build/macos/Build/Products/Release/" 2>/dev/null || true
  exit 1
fi
echo "==> App source: $APP_SRC"

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$STAGING"
mkdir -p "$STAGING"

echo "==> Staging as ${APP_FILE_NAME}…"
ditto --norsrc "$APP_SRC" "$STAGING/$APP_FILE_NAME"
xattr -cr "$STAGING" 2>/dev/null || true
find "$STAGING" -name '._*' -delete 2>/dev/null || true
find "$STAGING" -name '.DS_Store' -delete 2>/dev/null || true

PLIST="$STAGING/$APP_FILE_NAME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_DISPLAY_NAME}" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_DISPLAY_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_DISPLAY_NAME}" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${APP_DISPLAY_NAME}" "$PLIST"

EXEC_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || true)"
MACOS_DIR="$STAGING/$APP_FILE_NAME/Contents/MacOS"
if [[ -n "$EXEC_NAME" && -f "$MACOS_DIR/$EXEC_NAME" && "$EXEC_NAME" != "$APP_DISPLAY_NAME" ]]; then
  echo "==> Renaming executable → ${APP_DISPLAY_NAME}"
  mv "$MACOS_DIR/$EXEC_NAME" "$MACOS_DIR/$APP_DISPLAY_NAME"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_DISPLAY_NAME}" "$PLIST"
fi

if [[ -f "$APPICON_SRC" ]]; then
  echo "==> Embedding full AppIcon.icns from $APPICON_SRC"
  ICONSET_ROOT="$(mktemp -d)"
  ICONSET_APP="$ICONSET_ROOT/AppIcon.iconset"
  mkdir -p "$ICONSET_APP"
  icon_ok=1
  for base in 16 32 128 256 512; do
    if ! sips -s format png -z "$base" "$base" "$APPICON_SRC" --out "${ICONSET_APP}/icon_${base}x${base}.png" >/dev/null 2>&1; then
      icon_ok=0
      break
    fi
    d=$((base * 2))
    if ! sips -s format png -z "$d" "$d" "$APPICON_SRC" --out "${ICONSET_APP}/icon_${base}x${base}@2x.png" >/dev/null 2>&1; then
      icon_ok=0
      break
    fi
  done
  if [[ "$icon_ok" == "1" ]] && iconutil -c icns "$ICONSET_APP" -o "$STAGING/$APP_FILE_NAME/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    echo "==> AppIcon.icns OK"
  else
    echo "warning: could not rebuild AppIcon.icns — keeping Flutter-built icon" >&2
  fi
  rm -rf "$ICONSET_ROOT"
fi

# Xcode injects CFBundleIconName=AppIcon, so Finder/Dock read Assets.car
# (Flutter's default bird) and ignore the .icns we just embedded.
echo "==> Finder/Dock icon → AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true

echo "==> Codesign (Developer ID + hardened runtime): $DEVELOPER_ID_SIGNING_IDENTITY"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:---timestamp}"
codesign --force --deep $CODESIGN_TIMESTAMP --options runtime \
  --entitlements "$ROOT/macos/Runner/Release.entitlements" \
  --sign "$DEVELOPER_ID_SIGNING_IDENTITY" \
  "$STAGING/$APP_FILE_NAME"
codesign --verify --deep --strict --verbose=2 "$STAGING/$APP_FILE_NAME"
touch "$STAGING/$APP_FILE_NAME" "$STAGING/$APP_FILE_NAME/Contents"

echo "==> Generating styled DMG background (1320×840)…"
test -f "$LOGO" || { echo "error: logo missing: $LOGO" >&2; exit 1; }
swift "$ASSETS/make_dmg_background.swift" "$LOGO" "$BG_OUT"
ACTUAL="$(sips -g pixelWidth -g pixelHeight "$BG_OUT" 2>/dev/null | awk '/pixel/ {print $2}' | tr '\n' 'x' | sed 's/x$//')"
if [[ "$ACTUAL" != "1320x840" ]]; then
  sips -z 840 1320 "$BG_OUT" --out "$BG_OUT" >/dev/null
fi

VOLICON=""
if [[ -f "$APPICON_SRC" ]]; then
  ICONSET="$(mktemp -d)/EastmarkHKSnowball-VolumeIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$APPICON_SRC" --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -s format png -z "$double" "$double" "$APPICON_SRC" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
  done
  VOLICON="$(mktemp -t EastmarkHKSnowball-VolumeIcon).icns"
  iconutil -c icns "$ICONSET" -o "$VOLICON" || VOLICON=""
  rm -rf "$(dirname "$ICONSET")"
fi

rm -f "$DMG_FINAL" "$TMP_DMG"

APP_SIZE="$(du -sm "$STAGING" | cut -f1)"
DMG_SIZE=$((APP_SIZE + 40))

echo "==> Creating read-write DMG (${DMG_SIZE}m)…"
hdiutil create \
  -size "${DMG_SIZE}m" \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  "$TMP_DMG" >/dev/null

echo "==> Mounting…"
MOUNT_INFO="$(hdiutil attach "$TMP_DMG" -noautoopen)"
MOUNT_DIR="$(echo "$MOUNT_INFO" | grep -o '/Volumes/.*' | head -1)"
VOL_IN_VOLUMES="$(basename "$MOUNT_DIR")"
echo "==> Mounted at $MOUNT_DIR"

mkdir -p "$MOUNT_DIR/.background"
cp "$BG_OUT" "$MOUNT_DIR/.background/background.png"
ln -sf /Applications "$MOUNT_DIR/Applications"

echo "==> Applying Finder window layout…"
osascript <<EOF || echo "warning: Finder styling failed — continuing"
tell application "Finder"
  set volumeName to "${VOL_IN_VOLUMES}"
  set t to 0
  repeat while not (exists disk volumeName) and t < 15
    delay 1
    set t to t + 1
  end repeat
  if not (exists disk volumeName) then
    error "Disk " & volumeName & " not found after timeout"
  end if

  set theDisk to disk volumeName
  open theDisk
  delay 2
  set theWindow to container window of theDisk
  set bounds of theWindow to {400, 100, 1060, 520}
  set current view of theWindow to icon view
  set toolbar visible of theWindow to false
  set statusbar visible of theWindow to false
  set theViewOptions to the icon view options of theWindow
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to 96
  set text size of theViewOptions to 12
  set background picture of theViewOptions to file ".background:background.png" of theDisk
  set position of item "${APP_FILE_NAME}" of theDisk to {176, 238}
  set position of item "Applications" of theDisk to {484, 238}
  update theDisk
  delay 2
  close theWindow
end tell
EOF

sleep 2

if [[ -n "$VOLICON" && -f "$VOLICON" ]]; then
  cp "$VOLICON" "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  rm -f "$VOLICON"
fi

hdiutil detach "$MOUNT_DIR" >/dev/null
echo "==> Compressing…"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGING"

echo "==> Signing DMG…"
codesign --force $CODESIGN_TIMESTAMP --sign "$DEVELOPER_ID_SIGNING_IDENTITY" "$DMG_FINAL"

echo ""
echo "DMG ready (styled, app name: ${APP_DISPLAY_NAME}):"
echo "  $DMG_FINAL"
echo "  version ${MARKETING} (${BUILD})"
echo ""

if [[ "$NOTARIZE" != "1" ]]; then
  echo "Notarization skipped (NOTARIZE=0)."
  exit 0
fi

echo "==> Notarizing (keychain profile: $NOTARY_PROFILE)…"
xcrun notarytool submit "$DMG_FINAL" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_FINAL"
xcrun stapler validate "$DMG_FINAL"
echo ""
echo "Notarized + stapled:"
echo "  $DMG_FINAL"
