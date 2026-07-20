#!/bin/bash

# 发布已签名且公证的 DMG 到 GitHub Releases。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/dist"

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ 未安装 GitHub CLI（gh）。"
    exit 1
fi

VERSION="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "$PROJECT_ROOT/SwiftMenu.xcodeproj/project.pbxproj" | sort -u)"
if [[ -z "$VERSION" ]] || [[ "$VERSION" == *$'\n'* ]]; then
    echo "❌ 项目版本号不唯一，请先统一 MARKETING_VERSION。"
    exit 1
fi

TAG="v$VERSION"
DMG_PATH="$OUTPUT_DIR/SwiftMenu_${VERSION}.dmg"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ Git Tag $TAG 已存在，停止发布以避免覆盖历史版本。"
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ 工作区存在未提交修改，停止发布。"
    exit 1
fi

"$PROJECT_ROOT/scripts/build_and_package.sh" "$OUTPUT_DIR"

echo "📝 请输入发布说明，完成后按 Ctrl-D："
RELEASE_NOTES="$(</dev/stdin)"
if [[ -z "$RELEASE_NOTES" ]]; then
    RELEASE_NOTES="SwiftMenu $TAG：轻量、按需运行的 Finder 右键增强工具。"
fi

gh release create "$TAG" "$DMG_PATH" \
    --title "SwiftMenu $TAG" \
    --notes "$RELEASE_NOTES" \
    --target "$(git rev-parse HEAD)" \
    --repo wample0105/SwiftMenu

echo "✅ $TAG 已发布。"
