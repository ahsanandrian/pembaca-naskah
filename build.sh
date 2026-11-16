#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Pembaca Naskah.app"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_OUT="$BUILD_DIR/Pembaca_Naskah.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ICONSET_DIR" "$DMG_STAGING"

echo "1/4 Mengompilasi PembacaNaskah..."
swiftc -O "$ROOT_DIR/Sources/PembacaNaskah.swift" \
    -o "$APP_DIR/Contents/MacOS/PembacaNaskah" \
    -framework AppKit -framework PDFKit -framework QuartzCore -framework CoreImage

echo "2/4 Membuat AppIcon.icns..."
GEMINI_WORKSPACE_DIR="$BUILD_DIR" swift "$ROOT_DIR/Sources/make_icon.swift" || true
# Fallback: render iconset directly into $ICONSET_DIR
python3 - << PYEOF
import os, struct, subprocess, tempfile

# Run make_icon.swift with patched output path
with open("$ROOT_DIR/Sources/make_icon.swift") as f:
    code = f.read()

code = code.replace(
    'ProcessInfo.processInfo.environment["GEMINI_WORKSPACE_DIR"]! + "/offline_reader/AppIcon.iconset"',
    '"$ICONSET_DIR"'
)
tmp = tempfile.NamedTemporaryFile(suffix=".swift", delete=False, mode="w")
tmp.write(code)
tmp.close()
subprocess.run(["swift", tmp.name], check=True)
os.unlink(tmp.name)

entries = [
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]
chunks = bytearray()
for tag, fname in entries:
    with open(os.path.join("$ICONSET_DIR", fname), "rb") as f:
        data = f.read()
    chunks += tag + struct.pack(">I", len(data) + 8) + data

with open("$APP_DIR/Contents/Resources/AppIcon.icns", "wb") as f:
    f.write(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)
PYEOF

echo "3/4 Menulis Info.plist & menandatangani aplikasi..."
cat << 'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PembacaNaskah</string>
    <key>CFBundleIdentifier</key>
    <string>com.pandangdengrasa.pembacanaskah</string>
    <key>CFBundleName</key>
    <string>Pembaca Naskah</string>
    <key>CFBundleDisplayName</key>
    <string>Pembaca Naskah</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.2</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>pdf</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>PDF Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

echo "4/4 Membuat DMG installer..."
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$ROOT_DIR/PETUNJUK INSTALASI.txt" "$DMG_STAGING/"
hdiutil create -volname "Pembaca Naskah" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_OUT"

echo "Selesai:"
echo "- App : $APP_DIR"
echo "- DMG : $DMG_OUT"
