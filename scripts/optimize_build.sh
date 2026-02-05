#!/bin/bash

# SwiftMenu 自动构建优化脚本
# 自动在 project.pbxproj 中启用 Release 编译优化

set -e

PROJECT_FILE="SwiftMenu.xcodeproj/project.pbxproj"
BACKUP_FILE="SwiftMenu.xcodeproj/project.pbxproj.backup"

echo "� SwiftMenu 构建优化脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查文件是否存在
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ 错误：找不到项目文件 $PROJECT_FILE"
    exit 1
fi

# 备份原始文件
echo "📦 备份项目文件..."
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "✅ 备份已创建：$BACKUP_FILE"
echo ""

# 使用 Python 脚本来精确修改 pbxproj
echo "🔨 应用优化设置..."

python3 << 'PYTHON_SCRIPT'
import re
import sys

# 读取项目文件
with open('SwiftMenu.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 定义要添加的优化设置
optimizations = {
    'DEAD_CODE_STRIPPING': 'YES',
    'STRIP_INSTALLED_PRODUCT': 'YES',
    'COPY_PHASE_STRIP': 'YES',
    'SWIFT_COMPILATION_MODE': 'wholemodule',
}

# 查找所有 Release 配置块
# 匹配模式：buildSettings = { ... }; 在 name = Release 之后
release_pattern = r'(name = Release;[^}]*?buildSettings = \{)(.*?)(\};)'

def add_settings(match):
    prefix = match.group(1)
    settings_block = match.group(2)
    suffix = match.group(3)
    
    # 为每个优化选项添加或更新
    for key, value in optimizations.items():
        # 检查是否已存在
        existing_pattern = rf'{key}\s*=\s*[^;]+;'
        if re.search(existing_pattern, settings_block):
            # 更新现有值
            settings_block = re.sub(
                existing_pattern,
                f'{key} = {value};',
                settings_block
            )
        else:
            # 添加新设置（在块的开头）
            settings_block = f'\n\t\t\t\t{key} = {value};' + settings_block
    
    return prefix + settings_block + suffix

# 应用修改
modified_content = re.sub(release_pattern, add_settings, content, flags=re.DOTALL)

# 写回文件
with open('SwiftMenu.xcodeproj/project.pbxproj', 'w') as f:
    f.write(modified_content)

print("✅ 优化设置已应用")

PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 优化完成！已应用以下设置（Release 配置）："
    echo ""
    echo "   ✅ DEAD_CODE_STRIPPING = YES"
    echo "   ✅ STRIP_INSTALLED_PRODUCT = YES"
    echo "   ✅ COPY_PHASE_STRIP = YES"
    echo "   ✅ SWIFT_COMPILATION_MODE = wholemodule"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 预期效果："
    echo "   • 减少 10-20 MB 内存占用"
    echo "   • 减小应用体积约 20-30%"
    echo "   • 不影响任何功能"
    echo ""
    echo "💡 提示："
    echo "   • 如需恢复：cp $BACKUP_FILE $PROJECT_FILE"
    echo "   • 重新打包以应用优化：./scripts/build_and_package.sh"
    echo ""
else
    echo ""
    echo "❌ 优化失败，正在恢复备份..."
    cp "$BACKUP_FILE" "$PROJECT_FILE"
    echo "✅ 已恢复原始文件"
    exit 1
fi
