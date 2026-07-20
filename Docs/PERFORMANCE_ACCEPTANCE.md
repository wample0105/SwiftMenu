# SwiftMenu 生产性能验收

本清单用于签名安装后的 Release 包。Debug 构建、Xcode 注入运行和未安装的 `.appex` 不作为性能结论。

## 1. 构建与安全

- `./scripts/run_tests.sh` 全部通过。
- `./scripts/build_and_package.sh` 完成且无警告退出。
- `codesign --verify --deep --strict SwiftMenu.app` 通过。
- `xcrun stapler validate SwiftMenu_<版本>.dmg` 通过。
- `spctl --assess` 接受 DMG 和安装后的 App。

## 2. 空闲资源

安装并启用 Finder 扩展，Finder 保持空闲 10 分钟：

- SwiftMenu 主应用不应存在于进程列表。
- Finder 扩展平均 CPU 应接近 0%，目标小于 0.1%。
- Instruments 的 File Activity 中不应出现 SwiftMenu 周期写入。
- Instruments 的 System Trace 中不应出现 SwiftMenu 自建周期唤醒。
- RSS 记录实测值和系统版本，不以源码或二进制体积推算。

## 3. 启动与菜单响应

- 设置应用冷启动到窗口可交互：目标小于 500 ms，最多不得超过 1 秒。
- 独立基准中扩展初始化加首次菜单构造应小于 100 ms；Finder 拉起进程后的端到端首次菜单仍需单独记录。
- 连续打开右键菜单 100 次，菜单构造 p95 目标小于 16 ms，最大值小于 50 ms。
- 剪贴板为空、含文本、含单文件、含多文件四种状态均需测试。
- Home、外接磁盘和网络挂载卷均应出现预期菜单。

## 4. 文件操作与可靠性

- 复制 1 KB、100 MB、5 GB 文件时，Finder 主线程保持可交互。
- 复制包含 10,000 个小文件的目录时，右键菜单仍可正常打开。
- 验证跳过、保留两者、替换、取消和原地复制。
- 人为制造权限不足和磁盘空间不足，源文件与原目标文件不得丢失。
- 操作期间修改系统剪贴板，完成后不得清除用户的新剪贴板内容。
- 睡眠/唤醒、重启 Finder、禁用/重新启用扩展后不得出现恢复风暴。

## 5. 兼容矩阵

- macOS 12 最低支持版本。
- 当前稳定版 macOS。
- Apple Silicon 与 Intel 各至少一台设备或等价 CI/测试机。
- 全新安装与 v1.1.0 升级安装各一轮。

只有以上证据全部记录并通过后，才能声称发布包达到生产性能标准。
