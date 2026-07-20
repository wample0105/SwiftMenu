# SwiftMenu

<p align="center">
  <img src="assets/logo.png" alt="SwiftMenu Logo" width="120" height="120" />
</p>

<p align="center">
  <b>让 macOS Finder 拥有像 Windows 一样高效的右键增强菜单。</b>
</p>

<p align="center">
  <a href="README_EN.md">English</a> | 中文
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS-lightgrey.svg" alt="Platform" />
  <img src="https://img.shields.io/badge/语言-Swift-orange.svg" alt="Language" />
  <img src="https://img.shields.io/badge/许可证-MIT-blue.svg" alt="License" />
</p>

---

**SwiftMenu** 是一款原生且轻量级的 macOS Finder 扩展工具，它将 Windows 用户习惯的右键新建文件、复制路径等功能完美带到了 macOS。无需复杂配置，安装即可显著提升您的文件管理效率。

## ✨ 核心功能

- **📄 极速新建文件**：在当前目录下直接创建文件，支持 `.txt`, `.docx`, `.xlsx`, `.pptx`, `.md`。
- **🛠 实用效率工具**：
  - **复制路径**：一键复制选中文件或文件夹的完整绝对路径。
  - **在终端打开**：快速在当前目录唤起终端。
- **🎨 原生视觉体验**：与系统 UI 浑然一体，完美适配 SF Symbols。
- **⚙️ 高度可自定义**：在主应用中自由勾选菜单项并拖拽排序；关闭设置后主程序自动退出。
- **🌿 按需运行**：Finder 扩展由 macOS 管理，不使用轮询、心跳文件或后台保活进程。

## 📸 软件截图

<table align="center">
  <tr>
    <td align="center"><b>右键增强菜单</b></td>
    <td align="center"><b>自定义设置中心</b></td>
    <td align="center"><b>自定义菜单调整顺序</b></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshot_menu.png" alt="右键菜单截图" width="300" /></td>
    <td align="center"><img src="assets/screenshot_settings.png" alt="设置界面截图" width="300" /></td>
    <td align="center"><img src="assets/screenshot_menu_sort.png" alt="设置界面截图" width="300" /></td>
  </tr>
</table>

## 💻 系统要求

在安装 SwiftMenu 之前，请确保您的设备满足以下要求：

| 项目 | 最低要求 |
|------|---------|
| **操作系统** | macOS 12.0 (Monterey) 或更高版本 |
| **芯片** | Apple Silicon (M1/M2/M3/M4) 或 Intel 处理器 |

> 💡 **提示**：正式发布前会按照 `Docs/PERFORMANCE_ACCEPTANCE.md` 对最低支持版本和当前稳定版 macOS 做兼容验收。

## 🚀 安装指南

正式发布包使用 Developer ID 签名、Hardened Runtime 和 Apple 公证，可由 macOS Gatekeeper 正常验证。

### 1. 下载与安装
1. 前往 [Releases](https://github.com/wample0105/SwiftMenu/releases) 下载最新的 `SwiftMenu_<版本号>.dmg`。
2. 打开 DMG，将 `SwiftMenu.app` 拖入 **应用程序 (Applications)** 文件夹。
3. 正常双击运行 SwiftMenu 并完成菜单设置。

### 2. 启用 Finder 扩展
1. 打开 **系统设置** → **隐私与安全性** → **扩展**。
2. 点击 **Finder 扩展**，勾选 ✅ **SwiftMenu**。
3. 如果菜单没有立即显示，请右键点击 Dock 上的 Finder 图标并选择“重新启动”，或者在终端执行 `killall Finder`。

## 📝 使用方法

- **新建文件**：在 Finder 空白处或文件夹上右键，选择“新建...”并挑选文件类型。
- **复制路径**：右键点击文件或文件夹，选择“复制路径”。
- **在终端打开**：右键点击文件夹或空白处，选择“在终端打开”。
- **自定义菜单**：打开 SwiftMenu 主应用即可开启、关闭和排序功能项；关闭窗口后设置应用自动退出，不会后台常驻。

## ❓ 常见问题

- **Q: 为什么右键菜单没出来？**
  - A: 请检查“系统设置”中的“Finder 扩展”是否已勾选 SwiftMenu。若已勾选仍不显示，请尝试重启 Finder。
- **Q: 为什么关闭设置后，活动监视器里看不到 SwiftMenu 主程序？**
  - A: 这是正常现象。主程序只负责修改设置，右键菜单由 macOS 按需加载 Finder 扩展。
- **Q: 为什么打开设置时活动监视器里有两个 SwiftMenu 相关进程？**
  - A: 一个是设置主程序，另一个是 macOS 独立托管的“SwiftMenu Finder 扩展”，并非重复启动。关闭设置窗口后主程序会退出。
- **Q: 如何彻底停止 Finder 扩展？**
  - A: 在 SwiftMenu 常规设置中点击“管理 Finder 扩展…”，然后在系统设置中关闭 SwiftMenu。单纯退出设置主程序不会停用右键扩展。

## 🗑️ 卸载方法

1. 在“系统设置”中取消勾选 **SwiftMenu** 扩展。
2. 退出 SwiftMenu 进程。
3. 将应用程序文件夹中的 `SwiftMenu.app` 移除到废纸篓。

## ☕ 关注与交流

如果 SwiftMenu 对你有帮助，欢迎关注更新、加入交流群，或者请作者喝杯咖啡。

<table align="center">
  <tr>
    <td align="center"><b>关注公众号</b></td>
    <td align="center"><b>加我微信</b></td>
    <td align="center"><b>随喜支持</b></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/cta/apo-rpa-qrcode.png" alt="阿坡RPA 公众号二维码" width="180" /></td>
    <td align="center"><img src="assets/cta/apo-wechat-qrcode.png" alt="阿坡个人微信二维码" width="180" /></td>
    <td align="center"><img src="assets/cta/apo-donate-qrcode.png" alt="支持作者二维码" width="180" /></td>
  </tr>
  <tr>
    <td align="center"><b>阿坡RPA</b><br />获取 SwiftMenu 最新版本与实用工具</td>
    <td align="center"><b>阿坡</b><br />发送暗号「SwiftMenu」，加入专属交流群</td>
    <td align="center"><b>请作者喝杯咖啡</b><br />自愿打赏，感谢支持</td>
  </tr>
</table>

<p align="center">点击图片可查看原图，长按或右键可保存。</p>

## 🛠 开发与构建

1. 克隆仓库：`git clone https://github.com/wample0105/SwiftMenu.git`
2. 使用 Xcode 打开 `SwiftMenu.xcodeproj`。
3. 构建并运行 `SwiftMenu` Scheme。
4. 执行 `./scripts/run_tests.sh` 运行文件操作测试与 macOS 12 兼容类型检查。

生产构建使用 `./scripts/build_and_package.sh`。脚本会依次执行测试、Archive、Developer ID 导出、签名验证、DMG、公证、staple 和 Gatekeeper 验收；运行前需配置 `NOTARYTOOL_PROFILE`。

---
<p align="center">
  由 <a href="https://github.com/wample0105">阿坡</a> 用 ❤️ 制作
</p>
