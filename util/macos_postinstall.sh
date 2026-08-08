#!/bin/bash
# Sign and install Luanti.app for local development on macOS.
# iCloud-synced Documents adds metadata that breaks codesign in-place.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_APP="$ROOT/build/macos/luanti.app"
BIN="$ROOT/bin/luanti"
ENT="$ROOT/misc/macos/entitlements/debug.entitlements"
STAGE="/tmp/luanti-haxel.app"
DEST="${1:-$HOME/Applications/Luanti-Haxel.app}"

if [[ ! -f "$BIN" ]]; then
	echo "Missing $BIN — run 'make install' in build/ first." >&2
	exit 1
fi

rm -rf "$STAGE"
ditto --norsrc --noextattr "$SRC_APP" "$STAGE"
cp "$BIN" "$STAGE/Contents/MacOS/luanti"
chmod +x "$STAGE/Contents/MacOS/luanti"

FW="$STAGE/Contents/Frameworks"
if [[ ! -f "$FW/libSDL3.0.dylib" ]]; then
	cp "$(brew --prefix sdl3)/lib/libSDL3.0.dylib" "$FW/"
fi
ln -sf libSDL3.0.dylib "$FW/libSDL3.dylib"

rm -rf "$STAGE/Contents/_CodeSignature"
while IFS= read -r -d '' lib; do
	codesign --force --sign - "$lib"
done < <(find "$FW" -type f ! -type l -print0)

codesign --force --sign - --entitlements "$ENT" "$STAGE/Contents/MacOS/luanti"
codesign --force --deep --sign - --entitlements "$ENT" "$STAGE"

rm -rf "$DEST"
ditto "$STAGE" "$DEST"
codesign -vv --deep --strict "$DEST"

echo "Installed and signed: $DEST"
echo "Run: open \"$DEST\""
