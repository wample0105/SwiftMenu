#!/bin/bash

# SwiftMenu 自动化发版脚本
# 作用：打包应用 -> 创建 Git Tag -> 创建 GitHub Release -> 上传安装包

set -e

# 0. 检查 gh 工具是否安装
if ! command -v gh &> /dev/null; then
    echo "❌ 错误：未安装 GitHub CLI (gh)"
    echo "请运行 'brew install gh' 安装，并运行 'gh auth login' 登录"
    exit 1
fi

# 1. 获取版本号
echo "📌 请输入要发布的版本号 (例如 v1.0.1):"
read VERSION

if [[ -z "$VERSION" ]]; then
    echo "❌ 版本号不能为空"
    exit 1
fi

if [[ ! "$VERSION" =~ ^v ]]; then
    echo "⚠️  自动添加 'v' 前缀"
    VERSION="v$VERSION"
fi

echo "🚀 开始发布流程：$VERSION"
echo ""

# 2. 调用构建脚本进行打包
echo "📦 正在构建应用..."
./build_and_package.sh

# 检查构建产物
RELEASE_DIR=~/Desktop/SwiftMenu_Release
DMG_FILE="$RELEASE_DIR/SwiftMenu_Installer.dmg"
ZIP_FILE="$RELEASE_DIR/SwiftMenu_v1.0.zip" # 注意：这里如果版本号变了，zip名可能需要动态调整，目前脚本里是写死的v1.0

# 临时重命名 ZIP 以匹配版本号 (可选)
REAL_ZIP_FILE="$RELEASE_DIR/SwiftMenu_${VERSION}.zip"
mv "$ZIP_FILE" "$REAL_ZIP_FILE"

if [ ! -f "$DMG_FILE" ] || [ ! -f "$REAL_ZIP_FILE" ]; then
    echo "❌ 错误：找不到构建产物"
    exit 1
fi

# 3. 创建 Git Tag 并推送到远程
echo "🏷️  创建 Git Tag: $VERSION"
# 检查 tag 是否已存在
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "⚠️  Tag $VERSION 已存在，将覆盖 release..."
else
    git tag "$VERSION"
    git push origin "$VERSION"
fi

# 4. 创建 GitHub Release 并上传文件
echo "☁️  正在上传到 GitHub Release..."

gh release create "$VERSION" \
    "$DMG_FILE" \
    "$REAL_ZIP_FILE" \
    --title "SwiftMenu $VERSION" \
    --notes "SwiftMenu $VERSION 发布。包含安装包和完整压缩包。" \
    --repo wample0105/SwiftMenu

echo ""
echo "✅ 发布完成！"
echo "🔗 Release 链接：https://github.com/wample0105/SwiftMenu/releases/tag/$VERSION"
