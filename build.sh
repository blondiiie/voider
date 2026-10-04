#!/bin/bash
# Сборка Metka.app: бинарник + контент + Info.plist + ad-hoc подпись.
set -euo pipefail
cd "$(dirname "$0")"

APP="Metka.app"
echo "▸ swift build (release)…"
swift build -c release

echo "▸ Сборка бандла…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Metka "$APP/Contents/MacOS/Metka"

for f in video.mp4 video.mov video.webm photo.jpg photo.jpeg photo.png audio.mp3 audio.wav audio.m4a audio.aiff mask.png; do
  if [ -f "Content/$f" ]; then cp "Content/$f" "$APP/Contents/Resources/"; fi
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Метка</string>
    <key>CFBundleDisplayName</key><string>Метка</string>
    <key>CFBundleIdentifier</key><string>ru.ovdr.metka</string>
    <key>CFBundleExecutable</key><string>Metka</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSCameraUsageDescription</key>
    <string>Приложение «Метка» распознаёт лицо и жесты через камеру, чтобы показывать привязанный контент.</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▸ Подпись (ad-hoc)…"
codesign --force --sign - "$APP"

echo "✅ Готово: $APP"
echo "   Запуск: open $APP"
