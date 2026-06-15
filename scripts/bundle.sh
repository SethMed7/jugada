#!/bin/sh
# Builds Knight.app from the SwiftPM executable — no Xcode project needed.
# (The repo, bundle id, and config stay "jugada" under the hood; the product is "knight".)
set -e
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Knight.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Jugada "$APP/Contents/MacOS/Jugada"
cp Info.plist "$APP/Contents/Info.plist"

# Strip the debug symbol map. It embeds absolute build paths like
# /Users/<you>/jugada/.build/.../*.swift.o, which would otherwise ship in the
# public binary and leak your macOS username. Must run before codesign, since
# modifying the binary invalidates any signature.
strip -S "$APP/Contents/MacOS/Jugada"

# App icon: media/icon.png (1024px) -> jugada.icns, when present.
if [ -f media/icon.png ]; then
  ICONSET="build/jugada.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s media/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) media/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/jugada.icns"
fi

codesign --force --deep -s - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP"
