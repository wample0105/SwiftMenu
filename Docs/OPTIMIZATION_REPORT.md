# SwiftMenu v1.2.0 性能与可靠性优化报告

更新时间：2026-07-20

## 结论

v1.2.0 已从“主应用与扩展通过高频心跳相互保活”改为遵循 macOS App Extension 生命周期的按需架构。代码层面已经消除已知的周期磁盘 I/O、主线程文件复制、冲突弹窗死锁和破坏性覆盖路径。

运行时 CPU、RSS、唤醒次数和菜单延迟仍必须在签名安装的 Release 包上使用 Instruments 实测；任何未经实测的内存数字都不作为发布结论。

## 已完成优化

| 维度 | v1.1.0 | v1.2.0 |
|---|---|---|
| 扩展保活 | 每 3 秒原子写心跳文件 | 完全移除，由 macOS 管理 |
| 主应用检查 | 每 5 秒读取文件状态 | 完全移除 |
| 异常恢复 | 最快每 10 秒启动两次 `pluginkit` | 完全移除，不与用户或系统设置对抗 |
| 设置应用 | 菜单栏常驻并保留 SwiftUI 窗口 | 关闭最后一个窗口即退出 |
| 菜单配置 | 多次读取 Defaults、重复创建图标 | 单次一致性快照、静态缓存图标 |
| 文件操作 | 扩展回调线程同步预检、创建、复制/移动 | 串行后台队列、隐藏暂存后原子落位 |
| 冲突弹窗 | 主线程任务配合 semaphore | 无阻塞弹窗，返回后后台执行 |
| 替换策略 | 先删除目标再复制 | 同目录暂存成功后再替换 |
| 首次默认值 | 缺失 key 被当作 `false` | 使用 `register(defaults:)` |
| 文件权限 | Home 临时读写例外 + Terminal Apple Events | Developer ID 直装版保留 Home 与 `/Volumes/` 文件操作范围，移除 Apple Events；跨动作源文件使用安全书签 |
| Release | 普通 build + DMG | Archive + Developer ID + 公证验收 |

## 理论空闲工作量变化

在进程持续运行且定时器未被系统合并的情况下，旧版本每天理论上包含：

- 扩展约 28,800 次心跳文件写入；
- 主应用约 17,280 次心跳文件属性读取；
- 扩展不可用时可能持续启动 `pluginkit` 子进程。

v1.2.0 中上述周期任务均为 0。扩展空闲时没有自建 Timer、轮询和文件写入。

## 自动化证据

执行：

```bash
./scripts/run_tests.sh
```

当前 24 项核心测试覆盖：复制、原地复制、保留两者、跳过、安全替换、目录替换、移动、移动替换、原地移动、禁止复制目录到自身子目录、首次默认设置、菜单顺序修复、终端打开目标目录解析、安全书签单文件与多文件载荷往返、损坏载荷拒绝、系统文件 URL 与 SwiftMenu 安全书签的粘贴菜单识别、剪切标记和空剪贴板的反向判断，以及 Word/Excel/PowerPoint OOXML 完整性。同时使用 macOS 12 deployment target 对主应用及扩展进行严格并发检查，并将警告视为错误；存在 LibreOffice 时还会让办公套件实际解析并转换三个模板。

在当前 Apple Silicon 环境中，使用 `-O -whole-module-optimization` 和 macOS 12 target 完成链接级验证：主程序测试 Mach-O 为 252 KB，最终扩展测试 dylib 为 203,928 字节（约 199 KB）。该数据只证明代码体积与 Release 链接成功，不用于推算运行时 RSS。

扩展使用独立的 Foundation-only 设置读取器；`otool -L` 已确认扩展测试产物不链接 Combine 或 SwiftUI，避免仅为共享设置引入不必要的 UI/响应式框架。

优化编译下的独立冷路径（扩展初始化加首次菜单）最新为 56.207 ms，低于 100 ms 门槛；随后菜单构造 1,000 次的最终结果为 p50 0.023 ms、p95 0.031 ms、最大 0.214 ms，低于 p95 16 ms / 最大 50 ms 的门槛。该基准覆盖初始化、配置读取、剪贴板类型预检和 NSMenu 构造，但不包含 Finder 拉起扩展进程的端到端耗时。

以 Release 参数启动独立 Finder Sync 空闲测试壳，多次样本均为 CPU 0.0%、RSS 32,416–32,576 KB（约 31.7–31.8 MB），安全书签修复后的最新样本为 32,432 KB。该数值包含 AppKit/FinderSync 框架和测试壳基线，只用于发现定时器、轮询或异常常驻增长，不能替代安装后的 `.appex` 在 Finder 宿主中的 RSS、唤醒和文件活动测量。

使用当前 Apple Development 证书手工组装并签名的 Release 参数设置 App 已完成运行时抽检：进程出现约 101 ms，设置窗口无裁切，稳定后 CPU 约 0.1%、RSS 约 85.5 MB；关闭最后一个窗口后进程在 20 ms 内退出。由于缺少完整 Xcode，该数据不包含正式资源编译、Finder 扩展和 Developer ID 公证环境。

## Release 实机验收

完整 Xcode 与签名证书可用后，按照 [PERFORMANCE_ACCEPTANCE.md](PERFORMANCE_ACCEPTANCE.md) 完成冷启动、菜单延迟、空闲 CPU/RSS、系统唤醒、大目录复制、睡眠唤醒与 Finder 重启测试。
