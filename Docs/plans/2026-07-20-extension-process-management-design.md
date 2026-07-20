# SwiftMenu 进程与扩展管理交互设计

## 背景

SwiftMenu 包含设置主程序和 Finder Sync 扩展。两者由 macOS 以独立进程运行，但旧版扩展的 `CFBundleDisplayName` 同样是“SwiftMenu”，活动监视器因此显示两个同名条目，容易被误解为重复启动。

关闭最后一个设置窗口后，主程序应直接退出；Finder 扩展继续由 macOS 按需管理。主程序不能通过公开 API 强制永久关闭已启用的 Finder 扩展，单纯终止扩展进程也会被系统重新拉起，因此“彻底停用”必须交给系统扩展设置完成。

## 选定方案

1. 保持 `applicationShouldTerminateAfterLastWindowClosed = true`，不增加菜单栏常驻进程。
2. 将 Finder 扩展显示名称改为“SwiftMenu Finder 扩展”，与“SwiftMenu”设置主程序明确区分。
3. 在常规设置的“运行方式”区域说明两个进程的职责，并增加“管理 Finder 扩展…”按钮。
4. macOS 13 及以上优先打开“登录项与扩展”设置，macOS 12 使用旧扩展设置入口；若深层链接失败，则退回打开系统设置应用，并提示手动路径。
5. 不提供容易误导的“彻底退出”按钮，也不调用 `pluginkit`、`killall` 等非公开或破坏性命令。

## 验收标准

- 设置窗口关闭后主程序退出，Finder 右键菜单继续工作。
- 活动监视器可区分“SwiftMenu”和“SwiftMenu Finder 扩展”。
- “管理 Finder 扩展…”能打开当前系统的扩展管理入口；失败时有明确中文提示。
- macOS 12 deployment target 严格类型检查通过。
- App、Finder 扩展、ZIP 和 DMG 的最终签名与扩展显示名称校验通过。
