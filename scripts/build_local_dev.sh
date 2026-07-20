#!/bin/bash

# 在只有 Command Line Tools 的机器上生成 Apple Silicon 本地开发包。
# 产物使用 Apple Development 证书签名，不执行 Developer ID 公证。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/build}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftmenu-local-build.XXXXXX")"
APP_PATH="$WORK_DIR/SwiftMenu-dev.app"
APPEX_PATH="$APP_PATH/Contents/PlugIns/SwiftMenuFinderSync.appex"
ICONSET_PATH="$WORK_DIR/AppIcon.iconset"
DMG_SOURCE="$WORK_DIR/dmg-source"
DMG_MOUNT="$WORK_DIR/dmg-mount"
ZIP_EXTRACT="$WORK_DIR/zip-extract"
ZIP_PATH="$WORK_DIR/SwiftMenu-dev-arm64.zip"
DMG_PATH="$WORK_DIR/SwiftMenu-dev-arm64.dmg"
DMG_IS_MOUNTED=0

cleanup() {
    if [[ "$DMG_IS_MOUNTED" == "1" ]]; then
        hdiutil detach "$DMG_MOUNT" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

require_plist_value() {
    local plist_path="$1"
    local key_path="$2"
    local expected_value="$3"
    local actual_value

    actual_value="$(/usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" 2>/dev/null || true)"
    if [[ "$actual_value" != "$expected_value" ]]; then
        echo "❌ $plist_path 的 $key_path 应为 $expected_value，实际为 $actual_value"
        exit 1
    fi
}

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "❌ 本地开发脚本当前只生成 arm64 包。"
    exit 1
fi

SIGN_IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "❌ 钥匙串中没有可用的 Apple Development 签名证书。"
    exit 1
fi

echo "🧪 执行完整回归测试..."
"$PROJECT_ROOT/scripts/run_tests.sh"

mkdir -p \
    "$APP_PATH/Contents/MacOS" \
    "$APP_PATH/Contents/Resources/CTA" \
    "$APPEX_PATH/Contents/MacOS" \
    "$ICONSET_PATH" \
    "$DMG_SOURCE" \
    "$DMG_MOUNT" \
    "$ZIP_EXTRACT"

echo "🔨 编译 arm64 / macOS 12 Release 参数二进制..."
swiftc \
    -swift-version 5 \
    -target arm64-apple-macosx12.0 \
    -O \
    -whole-module-optimization \
    -module-name SwiftMenu \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppDelegate.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SettingsView.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SwiftMenuApp.swift" \
    -o "$APP_PATH/Contents/MacOS/SwiftMenu"

swiftc \
    -swift-version 5 \
    -target arm64-apple-macosx12.0 \
    -O \
    -whole-module-optimization \
    -parse-as-library \
    -application-extension \
    -module-name SwiftMenuFinderSync \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FileTransferEngine.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/TerminalLauncher.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FinderSync.swift" \
    -Xlinker -e \
    -Xlinker _NSExtensionMain \
    -o "$APPEX_PATH/Contents/MacOS/SwiftMenuFinderSync"

echo "🧩 组装 App Bundle 并展开 Xcode 构建变量..."
cp "$PROJECT_ROOT/Sources/SwiftMenu/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/Info.plist" "$APPEX_PATH/Contents/Info.plist"

APP_INFO="$APP_PATH/Contents/Info.plist"
APPEX_INFO="$APPEX_PATH/Contents/Info.plist"
plutil -replace CFBundleExecutable -string SwiftMenu "$APP_INFO"
plutil -replace CFBundleIdentifier -string com.aporightmenu.SwiftMenu "$APP_INFO"
plutil -replace CFBundleName -string SwiftMenu "$APP_INFO"
plutil -replace CFBundleShortVersionString -string 1.2.0 "$APP_INFO"
plutil -replace CFBundleVersion -string 1 "$APP_INFO"
plutil -replace LSMinimumSystemVersion -string 12.0 "$APP_INFO"

plutil -replace CFBundleExecutable -string SwiftMenuFinderSync "$APPEX_INFO"
plutil -replace CFBundleIdentifier -string com.aporightmenu.SwiftMenu.finder "$APPEX_INFO"
plutil -replace CFBundleName -string SwiftMenuFinderSync "$APPEX_INFO"
plutil -replace CFBundleShortVersionString -string 1.2.0 "$APPEX_INFO"
plutil -replace CFBundleVersion -string 1 "$APPEX_INFO"
plutil -replace LSMinimumSystemVersion -string 12.0 "$APPEX_INFO"
plutil -replace NSExtension.NSExtensionPrincipalClass -string SwiftMenuFinderSync.FinderSync "$APPEX_INFO"

plutil -convert binary1 "$APP_INFO" "$APPEX_INFO"
if strings "$APP_INFO" "$APPEX_INFO" | rg -q '\$\('; then
    echo "❌ Info.plist 仍含未展开的 Xcode 构建变量。"
    exit 1
fi

cp "$PROJECT_ROOT"/Sources/SwiftMenu/Resources/CTA/*.png "$APP_PATH/Contents/Resources/CTA/"
cp "$PROJECT_ROOT"/Sources/SwiftMenu/Assets.xcassets/AppIcon.appiconset/icon_*.png "$ICONSET_PATH/"
iconutil -c icns "$ICONSET_PATH" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

echo "🔏 签名并验证 App 与 Finder 扩展..."
codesign \
    --force \
    --options runtime \
    --timestamp=none \
    --entitlements "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SwiftMenuFinderSync.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APPEX_PATH"
codesign \
    --force \
    --options runtime \
    --timestamp=none \
    --entitlements "$PROJECT_ROOT/Sources/SwiftMenu/SwiftMenu.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_PATH"

codesign --verify --strict --verbose=2 "$APPEX_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

SIGNED_ENTITLEMENTS="$WORK_DIR/appex-entitlements.plist"
codesign -d --entitlements :- "$APPEX_PATH" >"$SIGNED_ENTITLEMENTS" 2>/dev/null
plutil -lint "$SIGNED_ENTITLEMENTS"
require_plist_value "$SIGNED_ENTITLEMENTS" ":'com.apple.security.app-sandbox'" "true"
require_plist_value "$SIGNED_ENTITLEMENTS" ":'com.apple.security.application-groups':0" "group.com.aporightmenu"
require_plist_value "$SIGNED_ENTITLEMENTS" ":'com.apple.security.files.user-selected.read-write'" "true"
require_plist_value "$SIGNED_ENTITLEMENTS" ":'com.apple.security.temporary-exception.files.home-relative-path.read-write':0" "/"
require_plist_value "$SIGNED_ENTITLEMENTS" ":'com.apple.security.temporary-exception.files.absolute-path.read-write':0" "/Volumes/"
require_plist_value "$APP_INFO" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu"
require_plist_value "$APPEX_INFO" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu.finder"
require_plist_value "$APPEX_INFO" ":CFBundleDisplayName" "SwiftMenu Finder 扩展"
require_plist_value "$APPEX_INFO" ":NSExtension:NSExtensionPrincipalClass" "SwiftMenuFinderSync.FinderSync"

if otool -L "$APPEX_PATH/Contents/MacOS/SwiftMenuFinderSync" | rg -q 'Combine|SwiftUI'; then
    echo "❌ Finder 扩展不应链接 Combine 或 SwiftUI。"
    exit 1
fi

echo "📦 生成并验收 ZIP 与 DMG..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
ditto "$APP_PATH" "$DMG_SOURCE/SwiftMenu.app"
ln -s /Applications "$DMG_SOURCE/Applications"
hdiutil create \
    -volname SwiftMenu \
    -srcfolder "$DMG_SOURCE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
codesign --force --timestamp=none --sign "$SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null

ditto -x -k "$ZIP_PATH" "$ZIP_EXTRACT"
ZIP_APP="$ZIP_EXTRACT/SwiftMenu-dev.app"
codesign --verify --deep --strict --verbose=2 "$ZIP_APP"
require_plist_value "$ZIP_APP/Contents/Info.plist" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu"
require_plist_value "$ZIP_APP/Contents/PlugIns/SwiftMenuFinderSync.appex/Contents/Info.plist" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu.finder"
require_plist_value "$ZIP_APP/Contents/PlugIns/SwiftMenuFinderSync.appex/Contents/Info.plist" ":CFBundleDisplayName" "SwiftMenu Finder 扩展"

hdiutil attach \
    -nobrowse \
    -readonly \
    -mountpoint "$DMG_MOUNT" \
    "$DMG_PATH" >/dev/null
DMG_IS_MOUNTED=1
DMG_APP="$DMG_MOUNT/SwiftMenu.app"
codesign --verify --deep --strict --verbose=2 "$DMG_APP"
require_plist_value "$DMG_APP/Contents/Info.plist" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu"
require_plist_value "$DMG_APP/Contents/PlugIns/SwiftMenuFinderSync.appex/Contents/Info.plist" ":CFBundleIdentifier" "com.aporightmenu.SwiftMenu.finder"
require_plist_value "$DMG_APP/Contents/PlugIns/SwiftMenuFinderSync.appex/Contents/Info.plist" ":CFBundleDisplayName" "SwiftMenu Finder 扩展"
for resource in apo-rpa-qrcode.png apo-wechat-qrcode.png apo-donate-qrcode.png; do
    cmp \
        "$PROJECT_ROOT/Sources/SwiftMenu/Resources/CTA/$resource" \
        "$DMG_APP/Contents/Resources/CTA/$resource"
done
hdiutil detach "$DMG_MOUNT" -quiet
DMG_IS_MOUNTED=0

mkdir -p "$OUTPUT_DIR"
BACKUP_DIR="$OUTPUT_DIR/previous/$(date +%Y%m%d-%H%M%S)"
for artifact in SwiftMenu-dev.app SwiftMenu-dev-arm64.zip SwiftMenu-dev-arm64.dmg; do
    if [[ -e "$OUTPUT_DIR/$artifact" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$OUTPUT_DIR/$artifact" "$BACKUP_DIR/$artifact"
    fi
done

mv "$APP_PATH" "$OUTPUT_DIR/SwiftMenu-dev.app"
mv "$ZIP_PATH" "$OUTPUT_DIR/SwiftMenu-dev-arm64.zip"
mv "$DMG_PATH" "$OUTPUT_DIR/SwiftMenu-dev-arm64.dmg"

codesign --verify --deep --strict --verbose=2 "$OUTPUT_DIR/SwiftMenu-dev.app"
codesign --verify --verbose=2 "$OUTPUT_DIR/SwiftMenu-dev-arm64.dmg"

echo "✅ 本地开发构建完成："
du -sh "$OUTPUT_DIR/SwiftMenu-dev.app"
stat -f '%N %z bytes' \
    "$OUTPUT_DIR/SwiftMenu-dev-arm64.zip" \
    "$OUTPUT_DIR/SwiftMenu-dev-arm64.dmg"
shasum -a 256 \
    "$OUTPUT_DIR/SwiftMenu-dev-arm64.zip" \
    "$OUTPUT_DIR/SwiftMenu-dev-arm64.dmg"
if [[ -d "$BACKUP_DIR" ]]; then
    echo "上一版已保留在：$BACKUP_DIR"
fi
