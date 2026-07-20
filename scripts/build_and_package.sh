#!/bin/bash

# 生产构建：测试 -> Archive -> Developer ID 导出 -> 签名验证 -> DMG -> 公证 -> 验收。
# 前置条件：完整 Xcode、Developer ID Application 证书、notarytool 钥匙串配置。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/dist}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftmenu-release.XXXXXX")"
ARCHIVE_PATH="$WORK_DIR/SwiftMenu.xcarchive"
EXPORT_DIR="$WORK_DIR/export"
DMG_SOURCE="$WORK_DIR/dmg"
DMG_MOUNT="$WORK_DIR/mount"
EXPORT_OPTIONS="$PROJECT_ROOT/scripts/ExportOptions.plist"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
DMG_IS_MOUNTED=0

cleanup() {
    if [[ "$DMG_IS_MOUNTED" == "1" ]]; then
        hdiutil detach "$DMG_MOUNT" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

require_entitlement() {
    local plist_path="$1"
    local key_path="$2"
    local expected_value="$3"
    local actual_value

    actual_value="$(/usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" 2>/dev/null || true)"
    if [[ "$actual_value" != "$expected_value" ]]; then
        echo "❌ $plist_path 缺少预期 entitlement：$key_path=$expected_value"
        exit 1
    fi
}

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "❌ 需要完整 Xcode；当前 xcode-select 没有指向 Xcode Developer 目录。"
    exit 1
fi

if [[ -z "$NOTARYTOOL_PROFILE" ]]; then
    echo "❌ 请设置 NOTARYTOOL_PROFILE（由 xcrun notarytool store-credentials 创建）。"
    exit 1
fi

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)}"
if [[ -z "$CODESIGN_IDENTITY" ]]; then
    echo "❌ 钥匙串中没有可用的 Developer ID Application 证书。"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$DMG_SOURCE"
mkdir -p "$DMG_MOUNT"

echo "🧪 执行自动化测试与源码类型检查..."
"$PROJECT_ROOT/scripts/run_tests.sh"

echo "📦 创建 Release Archive..."
xcodebuild \
    -project "$PROJECT_ROOT/SwiftMenu.xcodeproj" \
    -scheme SwiftMenu \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

echo "🔏 使用 Developer ID 导出..."
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

APP_PATH="$EXPORT_DIR/SwiftMenu.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ 导出结果中没有 SwiftMenu.app。"
    exit 1
fi

APPEX_PATH="$APP_PATH/Contents/PlugIns/SwiftMenuFinderSync.appex"
if [[ ! -d "$APPEX_PATH" ]]; then
    echo "❌ 导出 App 中没有嵌入 Finder Sync 扩展。"
    exit 1
fi

echo "🔍 验证 App、扩展签名与最终 entitlement..."
codesign --verify --strict --verbose=2 "$APPEX_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_ENTITLEMENTS="$WORK_DIR/app-entitlements.plist"
APPEX_ENTITLEMENTS="$WORK_DIR/appex-entitlements.plist"
codesign -d --entitlements :- "$APP_PATH" >"$APP_ENTITLEMENTS" 2>/dev/null
codesign -d --entitlements :- "$APPEX_PATH" >"$APPEX_ENTITLEMENTS" 2>/dev/null
plutil -lint "$APP_ENTITLEMENTS" "$APPEX_ENTITLEMENTS"

require_entitlement "$APP_ENTITLEMENTS" ":'com.apple.security.app-sandbox'" "true"
require_entitlement "$APP_ENTITLEMENTS" ":'com.apple.security.application-groups':0" "group.com.aporightmenu"
require_entitlement "$APPEX_ENTITLEMENTS" ":'com.apple.security.app-sandbox'" "true"
require_entitlement "$APPEX_ENTITLEMENTS" ":'com.apple.security.application-groups':0" "group.com.aporightmenu"
require_entitlement "$APPEX_ENTITLEMENTS" ":'com.apple.security.files.user-selected.read-write'" "true"
require_entitlement "$APPEX_ENTITLEMENTS" ":'com.apple.security.temporary-exception.files.home-relative-path.read-write':0" "/"
require_entitlement "$APPEX_ENTITLEMENTS" ":'com.apple.security.temporary-exception.files.absolute-path.read-write':0" "/Volumes/"

APPEX_DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APPEX_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ "$APPEX_DISPLAY_NAME" != "SwiftMenu Finder 扩展" ]]; then
    echo "❌ 最终 Finder 扩展显示名称未与设置主程序区分。"
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$OUTPUT_DIR/SwiftMenu_${VERSION}.dmg"

ditto "$APP_PATH" "$DMG_SOURCE/SwiftMenu.app"
ln -s /Applications "$DMG_SOURCE/Applications"

echo "💿 创建并签名 DMG..."
hdiutil create \
    -volname "SwiftMenu" \
    -srcfolder "$DMG_SOURCE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

echo "☁️ 提交 Apple 公证..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

echo "🧪 验证 DMG 中最终交付的 App..."
hdiutil attach \
    -nobrowse \
    -readonly \
    -mountpoint "$DMG_MOUNT" \
    "$DMG_PATH" >/dev/null
DMG_IS_MOUNTED=1

DISTRIBUTED_APP="$DMG_MOUNT/SwiftMenu.app"
DISTRIBUTED_APPEX="$DISTRIBUTED_APP/Contents/PlugIns/SwiftMenuFinderSync.appex"
if [[ ! -d "$DISTRIBUTED_APP" || ! -d "$DISTRIBUTED_APPEX" ]]; then
    echo "❌ DMG 中缺少 App 或 Finder Sync 扩展。"
    exit 1
fi

codesign --verify --strict --verbose=2 "$DISTRIBUTED_APPEX"
codesign --verify --deep --strict --verbose=2 "$DISTRIBUTED_APP"
spctl --assess --type execute --verbose=2 "$DISTRIBUTED_APP"

hdiutil detach "$DMG_MOUNT" -quiet
DMG_IS_MOUNTED=0

echo "✅ 生产安装包已生成并通过签名、公证验收：$DMG_PATH"
