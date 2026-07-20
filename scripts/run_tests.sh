#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/swiftmenu-tests.XXXXXX")"
trap 'rm -rf "$TEST_OUTPUT"' EXIT

EXTENSION_ENTITLEMENTS="$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SwiftMenuFinderSync.entitlements"
EXTENSION_INFO="$PROJECT_ROOT/Sources/SwiftMenuFinderSync/Info.plist"
HOME_EXCEPTION="$(/usr/libexec/PlistBuddy -c "Print :'com.apple.security.temporary-exception.files.home-relative-path.read-write':0" "$EXTENSION_ENTITLEMENTS" 2>/dev/null || true)"
VOLUMES_EXCEPTION="$(/usr/libexec/PlistBuddy -c "Print :'com.apple.security.temporary-exception.files.absolute-path.read-write':0" "$EXTENSION_ENTITLEMENTS" 2>/dev/null || true)"
if [[ "$HOME_EXCEPTION" != "/" || "$VOLUMES_EXCEPTION" != "/Volumes/" ]]; then
    echo "❌ Finder 扩展缺少新建/粘贴所需的 Home 或 /Volumes 读写 entitlement。"
    exit 1
fi
echo "Finder 扩展目录写入 entitlement 检查通过。"

EXTENSION_DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$EXTENSION_INFO" 2>/dev/null || true)"
if [[ "$EXTENSION_DISPLAY_NAME" != "SwiftMenu Finder 扩展" ]]; then
    echo "❌ Finder 扩展显示名称未与设置主程序区分。"
    exit 1
fi
echo "Finder 扩展进程显示名称检查通过。"

swiftc \
    -swift-version 5 \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FileTransferEngine.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/TerminalLauncher.swift" \
    "$PROJECT_ROOT/Tests/FileTransferEngineTests.swift" \
    -o "$TEST_OUTPUT/FileTransferEngineTests"

"$TEST_OUTPUT/FileTransferEngineTests"

if command -v soffice >/dev/null 2>&1; then
    mkdir -p "$TEST_OUTPUT/office-input" "$TEST_OUTPUT/office-output"
    swiftc \
        -swift-version 5 \
        -O \
        "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
        "$PROJECT_ROOT/Tests/GenerateOfficeTemplates.swift" \
        -o "$TEST_OUTPUT/GenerateOfficeTemplates"
    "$TEST_OUTPUT/GenerateOfficeTemplates" "$TEST_OUTPUT/office-input"

    if ! soffice \
        "-env:UserInstallation=file://$TEST_OUTPUT/libreoffice-profile" \
        --headless \
        --convert-to pdf \
        --outdir "$TEST_OUTPUT/office-output" \
        "$TEST_OUTPUT/office-input/空白文档.docx" \
        "$TEST_OUTPUT/office-input/空白表格.xlsx" \
        "$TEST_OUTPUT/office-input/空白演示.pptx" \
        >"$TEST_OUTPUT/office-validation.log" 2>&1; then
        sed -n '1,160p' "$TEST_OUTPUT/office-validation.log"
        echo "❌ LibreOffice 无法解析 OOXML 模板。"
        exit 1
    fi

    OFFICE_PDF_COUNT="$(find "$TEST_OUTPUT/office-output" -type f -name '*.pdf' | wc -l | tr -d ' ')"
    if [[ "$OFFICE_PDF_COUNT" != "3" ]]; then
        sed -n '1,160p' "$TEST_OUTPUT/office-validation.log"
        echo "❌ OOXML 模板解析结果不完整。"
        exit 1
    fi
    echo "✅ Word、Excel、PowerPoint 模板通过 LibreOffice 实际解析。"
else
    echo "ℹ️ 未安装 LibreOffice，已跳过可选的办公套件实际解析测试。"
fi

swiftc \
    -swift-version 5 \
    -target "$(uname -m)-apple-macosx12.0" \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    -O \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FileTransferEngine.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/TerminalLauncher.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FinderSync.swift" \
    "$PROJECT_ROOT/Tests/MenuConstructionBenchmark.swift" \
    -o "$TEST_OUTPUT/MenuConstructionBenchmark"

"$TEST_OUTPUT/MenuConstructionBenchmark"

swiftc \
    -swift-version 5 \
    -target "$(uname -m)-apple-macosx12.0" \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    -O \
    -whole-module-optimization \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FileTransferEngine.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/TerminalLauncher.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FinderSync.swift" \
    "$PROJECT_ROOT/Tests/FinderSyncIdleHarness.swift" \
    -o "$TEST_OUTPUT/FinderSyncIdleHarness"

"$TEST_OUTPUT/FinderSyncIdleHarness" >"$TEST_OUTPUT/finder-sync-idle.log" 2>&1 &
IDLE_HARNESS_PID=$!
sleep 2
IDLE_SAMPLE="$(ps -p "$IDLE_HARNESS_PID" -o %cpu=,rss= | xargs)"
wait "$IDLE_HARNESS_PID"

if [[ -z "$IDLE_SAMPLE" ]]; then
    sed -n '1,80p' "$TEST_OUTPUT/finder-sync-idle.log"
    echo "❌ Finder Sync 空闲基准未能取得运行样本。"
    exit 1
fi

echo "Finder Sync 独立空闲基准（非 Finder 宿主验收）：CPU/RSS(KB) $IDLE_SAMPLE"

swiftc -swift-version 5 -typecheck \
    -target "$(uname -m)-apple-macosx12.0" \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FileTransferEngine.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/OfficeDocumentFactory.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/TerminalLauncher.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenuFinderSync/FinderSync.swift"

swiftc -swift-version 5 -typecheck \
    -target "$(uname -m)-apple-macosx12.0" \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppDelegate.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SettingsView.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SwiftMenuApp.swift"

swiftc \
    -swift-version 5 \
    -target "$(uname -m)-apple-macosx12.0" \
    -strict-concurrency=complete \
    -warn-concurrency \
    -warnings-as-errors \
    -O \
    -whole-module-optimization \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppSettings.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/AppDelegate.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SettingsView.swift" \
    "$PROJECT_ROOT/Sources/SwiftMenu/SwiftMenuApp.swift" \
    -o "$TEST_OUTPUT/SwiftMenuLinkCheck"

echo "SwiftMenu 源码类型检查与 Release 参数链接检查通过。"
