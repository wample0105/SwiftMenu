#!/bin/bash

# SwiftMenu 一键打包脚本
# 使用方法：chmod +x build_and_package.sh && ./build_and_package.sh

set -e  # 遇到错误就停止

echo "🚀 开始打包 SwiftMenu..."
echo ""

# 1. 设置路径与清理
PRJ_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PRJ_ROOT"

echo "📦 步骤 1/6: 清理旧构建..."
xcodebuild -scheme SwiftMenu -configuration Release clean > /dev/null 2>&1
echo "✅ 清理完成"
echo ""

# 2. 编译 Release 版本
echo "🔨 步骤 2/6: 编译 Release 版本 (这可能需要1-2分钟)..."
xcodebuild -scheme SwiftMenu -configuration Release -allowProvisioningUpdates build > /tmp/xcode_build.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 编译成功"
else
    echo "❌ 编译失败，查看详细日志："
    tail -50 /tmp/xcode_build.log
    exit 1
fi
echo ""

# 3. 准备发布目录
echo "📁 步骤 3/6: 准备发布目录..."
RELEASE_DIR=~/Desktop/SwiftMenu_Release
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR/dmg_temp"

# 获取构建产物路径 (科学获取方式)
BUILD_DIR=$(xcodebuild -scheme SwiftMenu -configuration Release -showBuildSettings | grep -m 1 BUILT_PRODUCTS_DIR | cut -d'=' -f2 | xargs)
BUILD_APP="$BUILD_DIR/SwiftMenu.app"

if [ -d "$BUILD_APP" ]; then
    cp -R "$BUILD_APP" "$RELEASE_DIR/dmg_temp/"
    echo "✅ App 已复制到发布目录"
else
    echo "❌ 找不到编译后的 App：$BUILD_APP"
    exit 1
fi

# 创建 Applications 符号链接
ln -s /Applications "$RELEASE_DIR/dmg_temp/Applications"
echo ""

# 4. 创建 DMG
echo "💿 步骤 4/6: 创建 DMG 安装包..."
cd "$RELEASE_DIR"
hdiutil create -volname "SwiftMenu" \
    -srcfolder dmg_temp \
    -ov -format UDZO \
    -fs HFS+ \
    SwiftMenu_Installer.dmg > /dev/null 2>&1
    
if [ $? -eq 0 ]; then
    echo "✅ DMG 创建成功"
    rm -rf dmg_temp
else
    echo "❌ DMG 创建失败"
    exit 1
fi
echo ""

# 5. 复制文档
echo "📝 步骤 5/6: 复制文档..."
cp "$PRJ_ROOT/README.md" "$RELEASE_DIR/"
cp "$PRJ_ROOT/README_EN.md" "$RELEASE_DIR/"
mkdir -p "$RELEASE_DIR/assets"
cp "$PRJ_ROOT/assets/"*.png "$RELEASE_DIR/assets/" 2>/dev/null || true
echo "✅ 说明文档与资源已复制"
echo ""

# 6. 创建 ZIP 完整包
echo "🗜️  步骤 6/6: 创建 ZIP 压缩包..."
zip -r SwiftMenu_v1.0.zip SwiftMenu_Installer.dmg README.md README_EN.md assets > /dev/null 2>&1
echo "✅ ZIP 创建成功"
echo ""

# 显示结果
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 打包完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 输出位置：$RELEASE_DIR"
echo ""
ls -lh "$RELEASE_DIR" | grep -E "(dmg|zip|README)"
echo ""
echo "🚀 可以分发以下文件："
echo "   • SwiftMenu_Installer.dmg (专业安装包)"
echo "   • SwiftMenu_v1.0.zip (完整压缩包)"
echo ""
echo "💡 提示：双击 DMG 测试安装效果"
echo ""
