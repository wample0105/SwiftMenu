# RightMenu

<p align="center">
  <img src="ApoRightMenu/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="RightMenu Logo" width="120" height="120" />
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

**RightMenu** 是一款原生且轻量级的 macOS Finder 扩展工具，它将 Windows 用户习惯的右键新建文件、复制路径等功能完美带到了 macOS。无需复杂配置，安装即可显著提升您的文件管理效率。

## ✨ 核心功能

- **📄 极速新建文件**
  在当前目录下直接创建文件，支持：
  - 文本文档 (`.txt`)
  - Word 文档 (`.docx`)
  - Excel 表格 (`.xlsx`)
  - PPT 演示文稿 (`.pptx`)
  - Markdown 文件 (`.md`)

- **🛠 实用效率工具**
  - **复制路径**：一键复制选中文件或文件夹的完整绝对路径。
  - **在终端打开**：快速在当前目录唤起终端，省去 `cd` 操作。

- **🎨 原生视觉体验**
  - 使用 **Swift** 语言与 **FinderSync** 框架原生打造。
  - 完美适配 **SF Symbols**，与系统 UI 浑然一体。
  - 极简代码，低内存占用，不影响系统响应速度。

- **⚙️ 高度可自定义**
  - 在主应用中自由勾选需要显示的菜单项。
  - 支持 **开机自动启动**，让效率工具时刻就绪。

## 📸 软件截图

<table align="center">
  <tr>
    <td align="center"><b>右键增强菜单</b></td>
    <td align="center"><b>自定义设置中心</b></td>
  </tr>
  <tr>
    <td align="center"><img src="Docs/screenshot_menu.png" alt="右键菜单截图" width="300" /></td>
    <td align="center"><img src="Docs/screenshot_settings.png" alt="设置界面截图" width="300" /></td>
  </tr>
</table>

## 📥 安装指南

### 1. 下载程序
前往 [Releases](https://github.com/your_username/RightMenu/releases) 页面，下载最新的 `RightMenu_v1.0.zip` 或 `.dmg` 安装包。

### 2. 安装与运行
1. 将 `RightMenu.app` 拖入 **应用程序 (Applications)** 文件夹。
2. **首次启动**：右击图标后选择“打开”，在安全提示中再次点击“打开”。

### 3. 启用 Finder 扩展
1. 打开 **系统设置**。
2. 导航至 **隐私与安全性** -> **扩展**。
3. 进入 **Finder 扩展**。
4. 勾选 **RightMenu**。

> **提示**：如果菜单没有立即显示，请右键点击 Dock 上的 Finder 图标并选择“重新启动”，或者在终端执行 `killall Finder`。

## 🛠 开发与构建

### 开发要求
- macOS 13.0+
- Xcode 14.0+
- Swift 5.0+

### 从源码构建
1. 克隆仓库：
   ```bash
   git clone https://github.com/your_username/RightMenu.git
   ```
2. 在 Xcode 中打开 `ApoRightMenu.xcodeproj`。
3. 在 **Signing & Capabilities** 中选择您的开发团队。
4. 构建并运行 `ApoRightMenu` Scheme。

## 🤝 参与贡献

我们非常欢迎您的贡献！如果您有新的功能点子或发现了 Bug，欢迎提交 Issue 或 Pull Request。

1. Fork 本项目
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 发起 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 `LICENSE` 文件。

---
<p align="center">
  由 <a href="https://github.com/your_username">阿坡</a> 用 ❤️ 制作
</p>
