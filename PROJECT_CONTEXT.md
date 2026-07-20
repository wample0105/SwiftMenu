# SwiftMenu 项目上下文

更新时间：2026-07-20

## 产品定位

SwiftMenu 是 macOS Finder Sync 扩展，在 Finder 右键菜单中提供新建文件、剪切、复制、粘贴、复制路径和在终端打开。最低支持 macOS 12，目标是按需运行、低内存、接近零空闲 CPU/磁盘 I/O，并与 Finder 原生菜单一致。

## 当前架构（v1.2.0）

- `Sources/SwiftMenu`：仅用于修改共享设置。关闭最后一个设置窗口后主进程自动退出，不提供菜单栏常驻或开机自启。
- `Sources/SwiftMenuFinderSync`：由 macOS/Finder 按需管理，不使用 Timer、心跳文件、轮询、`pluginkit` 强制恢复。
- 主应用与扩展通过 App Group `group.com.aporightmenu` 共享 `UserDefaults`。
- 扩展使用 Foundation-only 的设置读取器，不链接 Combine/SwiftUI；`otool -L` 链接检查已验证。
- 右键菜单每次构造只读取一份配置快照，SF Symbols 使用静态缓存。
- 新建文件、粘贴冲突预检、文件复制与移动均在单并发后台队列执行；冲突支持保留两者、跳过、替换和取消，慢速网络盘 I/O 不占用菜单主线程。
- 普通复制和替换均先写入目标目录旁的隐藏暂存项，再原子落位；同卷移动使用快速 rename，跨卷移动在安全复制完成后才删除源文件。
- 复制/剪切动作将 Finder 提供的临时源文件权限编码为自定义剪贴板安全书签；粘贴动作恢复源文件和目标目录的 scoped URL，再交给后台队列，权限不会随菜单动作返回而丢失。
- Word、Excel、PowerPoint 新建功能在内存中生成最小合法 OOXML ZIP，不依赖第三方运行库；LibreOffice 实际解析验证已通过。
- Finder Sync 的 `targetedURL` / `selectedItemURLs` 只提供上下文路径，不等同于打开/保存面板授予的 Powerbox 文件权限。Developer ID 直装版扩展显式申请 Home 与 `/Volumes/` 读写临时例外；安全书签负责延续跨菜单动作的源文件权限，两者不能互相替代。
- “在终端打开”通过 macOS 自带的 “New Terminal at Folder” 系统服务调用 Terminal，只在专用 pasteboard 中短暂传递路径文本，不把目录 URL 交给 Launch Services，也不创建 `/usr/bin/open` 子进程。
- 设置主程序和 Finder 扩展是 macOS 要求的独立进程；扩展显示名为“SwiftMenu Finder 扩展”，避免活动监视器出现两个同名 SwiftMenu。常规设置提供“管理 Finder 扩展…”入口，彻底停用必须在系统扩展设置中完成。

## 生产约束

- Release 版本启用 Swift `-O`、Whole Module Optimization、Dead Code Stripping、Hardened Runtime 和产品验证。
- `scripts/build_and_package.sh` 要求完整 Xcode、Developer ID Application 证书和 `NOTARYTOOL_PROFILE`，执行 Archive、导出、App/嵌入扩展签名与实际 entitlement 验证、DMG 公证、staple，并挂载 DMG 对最终分发 App 执行 Gatekeeper 验收。
- 当前开发环境只有 Command Line Tools，没有完整 Xcode；钥匙串只有 Apple Development 证书，没有 Developer ID Application 证书。因此可执行 Swift 类型检查、Release 参数链接和核心测试，但不能生成/运行生产签名 `.app`、提交公证或完成 Instruments 实测。

## 验证命令

```bash
./scripts/run_tests.sh
bash -n scripts/build_and_package.sh scripts/release.sh scripts/run_tests.sh
plutil -lint SwiftMenu.xcodeproj/project.pbxproj
git diff --check
```

当前有 24 项核心逻辑测试：复制、原地复制、保留两者、跳过、安全替换、安全替换目录、移动、移动并替换、原地移动、阻止复制目录到自身子目录、首次默认设置、菜单顺序修复、终端打开目录/文件目标解析、安全书签单文件与多文件载荷往返、损坏载荷拒绝、系统文件 URL 与 SwiftMenu 安全书签的粘贴菜单识别、剪切标记和空剪贴板反向判断，以及三种 Office 模板。测试脚本同时按 macOS 12 deployment target 对主应用和扩展执行严格并发检查，并将警告视为错误；如果存在 LibreOffice，还会执行真实办公套件解析。

使用 `-O -whole-module-optimization` 与 macOS 12 target 的链接级验证已通过；Apple Silicon 下主程序测试 Mach-O 为 252 KB，最终扩展测试 dylib 为 203,928 字节（约 199 KB）。`otool -L` 再次确认扩展不链接 Combine/SwiftUI。此结果不是完整 App Bundle 或运行时内存数据。

独立基准以 `-O` 执行，2026-07-20 安全书签修复后的完整回归结果：扩展初始化加首次菜单 56.207 ms；随后 1,000 次菜单构造 p50 0.023 ms、p95 0.031 ms、最大 0.214 ms。它覆盖代码冷路径和菜单构造核心路径，但不包含 Finder 拉起扩展进程的端到端耗时，不能替代签名扩展在 Finder 宿主中的 Instruments 实测。

Release 参数的独立 Finder Sync 空闲测试壳多次样本均为 CPU 0.0%、RSS 32,416–32,576 KB（约 31.7–31.8 MB），安全书签修复后的最新样本为 32,432 KB。`scripts/run_tests.sh` 会重复执行该趋势检查；它不在 Finder 宿主内运行，只用于发现空闲轮询、定时器或异常内存增长，不能作为最终扩展 RSS/唤醒验收。

使用 Apple Development 证书手工组装的 Release 参数设置 App 已成功运行：进程出现约 101 ms，窗口视觉检查无裁切，稳定后 CPU 约 0.1%、RSS 约 85.5 MB；关闭最后一个窗口后进程在 20 ms 内退出。该测试不包含正式 asset catalog、嵌入扩展或 Developer ID 公证链路。

## 待完成的实机验收

按照 `Docs/PERFORMANCE_ACCEPTANCE.md`，在安装并启用的签名 Release 包上测量冷启动、右键菜单 p95、RSS、空闲 CPU、系统唤醒、文件活动、大目录复制、睡眠唤醒、Finder 重启以及 macOS/CPU 兼容矩阵。没有这些实测数据前，不应宣称所有生产性能指标已经最终达标。

2026-07-20 完成审计再次确认：当前机器的 active developer directory 是 `/Library/Developer/CommandLineTools`，`xcodebuild` 不可用；钥匙串没有 Developer ID Application 证书，只有 Apple Development 证书。生产构建脚本现已验证导出 App、嵌入 Finder 扩展及其实际签名 entitlement，并会挂载公证 DMG 对最终交付 App 执行 Gatekeeper 验收；entitlement 提取与断言逻辑已用临时签名产物验证，但完整链路只能在上述外部条件具备后运行。

Apple 官方资料确认 Finder Sync 的 `targetedURL` / `selectedItemURLs` 只在菜单构造及菜单动作中有效，但没有说明该 URL 会获得 Powerbox 动态沙盒扩展。实机中新建文件与粘贴目标目录均被拒绝，说明捕获路径和创建安全书签不能凭空获得写权限。当前 Developer ID 直装实现因此为扩展增加 `com.apple.security.temporary-exception.files.home-relative-path.read-write` 的 `/`，以及 `com.apple.security.temporary-exception.files.absolute-path.read-write` 的 `/Volumes/`；这适合直装分发，不应被视为 Mac App Store 兼容方案。长期收紧方向是让 Finder 扩展保持 UI-only，通过经过身份校验的按需辅助进程执行文件操作。

## 主程序与 Finder 扩展进程管理

2026-07-20 用户在活动监视器中看到两个名为 SwiftMenu 的条目。实机核对确认并非重复启动：一个是设置主程序，另一个是 `com.aporightmenu.SwiftMenu.finder` Finder Sync 扩展。Apple Finder Sync 架构要求扩展由 macOS 以独立进程托管，打开/保存面板还可能创建额外扩展实例，因此设置窗口打开时无法也不应强行合并成单进程；稳态目标仍是关闭最后一个设置窗口后只剩按需扩展。

扩展 `CFBundleDisplayName` 已改为“SwiftMenu Finder 扩展”，活动监视器不再显示两个同名 SwiftMenu。常规设置“运行方式”区域新增“管理 Finder 扩展…”按钮：macOS 13 及以上优先打开 `com.apple.LoginItems-Settings.extension`，macOS 12 使用旧扩展设置入口，深层链接失败时退回打开系统设置应用并显示中文手动路径。主程序不调用 `pluginkit` 或 `killall`，因为杀掉进程不能永久停用系统托管扩展；彻底退出必须由用户在系统设置中关闭 Finder 扩展。设计记录位于 `Docs/plans/2026-07-20-extension-process-management-design.md`。

验证已确认当前 macOS 26.5.1 能将新旧两个 `x-apple.systempreferences` 深层链接解析到 `/System/Applications/System Settings.app`；macOS 12 deployment target 严格类型检查通过。常规设置页实际窗口截图为 968×518，新增说明、按钮和三组设置无裁切、重叠或异常增高。

## 当前本地构建产物

2026-07-20 修复右键新建、目标目录权限和粘贴菜单识别，并增加扩展进程管理入口后，在只有 Command Line Tools 的环境中重新生成了 Apple Silicon 本地开发构建：`build/SwiftMenu-dev.app`（磁盘占用约 960 KB）、`build/SwiftMenu-dev-arm64.zip`（384,881 字节），以及 `build/SwiftMenu-dev-arm64.dmg`（607,410 字节）。主程序、Finder 扩展和 DMG 均使用现有 Apple Development 证书签名，团队标识为 `WAMMVMZR92`；二进制均为 arm64、最低系统版本 macOS 12.0，并启用 Hardened Runtime。嵌套签名、实际 entitlement、无 Combine/SwiftUI 依赖、ZIP 解压、DMG 校验与只读挂载、内部 App 深度签名均通过。包内 `AppIcon.icns` 使用方案 3 Logo，三张 CTA 二维码已逐一与源码资源比对；最终扩展同时包含终端系统服务入口、安全书签剪贴板载荷、Home `/` 与 `/Volumes/` 读写例外，显示名称为“SwiftMenu Finder 扩展”。手工构建显式展开 Xcode 平时负责替换的 Bundle ID、版本、最低系统和扩展主类变量，ZIP 与 DMG 中的主 App ID 为 `com.aporightmenu.SwiftMenu`，扩展 ID 为 `com.aporightmenu.SwiftMenu.finder`。最新重构建时间为 2026-07-20 17:16 CST；ZIP SHA-256 为 `f42502b503fab02960547fc740d83a08df14a26972542fbda7370e97f8af145c`，DMG SHA-256 为 `a3e7db400a215813ef4b3646512275f68d0dce126313baa0e6fcad8c7245a458`。上一版已保留在 `build/previous/20260720-171602`。

为避免重复手工构建遗漏元数据或 entitlement，新增 `scripts/build_local_dev.sh`：自动执行完整测试、arm64/macOS 12 Release 参数编译、Info.plist 变量展开、图标和 CTA 资源组装、Apple Development 签名、最终 entitlement 断言、ZIP 解压检查、DMG 校验/只读挂载检查，并把旧产物移动到带时间戳的 `build/previous/` 目录。

该产物仅包含 arm64 架构，使用开发证书且未经 Apple 公证，适用于当前 Apple Silicon Mac 的本地调试；它不是面向其他用户分发的通用/生产安装包。正式发行仍必须使用完整 Xcode 构建 universal 或目标架构 Archive，并完成 Developer ID 和公证链路。

## “在终端打开”权限修复

2026-07-20 用户实机报告两类错误：Terminal.app 启动出现“杂项错误”，以及系统提示 SwiftMenu 无权打开当前 `build` 目录。根因是 Finder Sync 扩展运行在 App Sandbox 中，原实现将目录文件 URL 作为 Launch Services 的打开文档参数交给 Terminal，系统会按发起方 SwiftMenu 的沙盒权限再次校验该 URL；`startAccessingSecurityScopedResource()` 不能把仅属于当前进程的动态沙盒扩展自动转给 Terminal。

修复实现位于 `Sources/SwiftMenuFinderSync/TerminalLauncher.swift`：根据右键目标是文件还是目录解析工作目录，通过独立命名的 pasteboard 向 Terminal 内置的 “New Terminal at Folder” NSServices 入口传递纯路径文本，调用结束后立即清空。该入口不引入 Apple Events/AppleScript 自动化权限或授权弹窗。使用真实源码构建的最小 App Sandbox 签名探针已对项目 `build` 目录返回 `terminal_service=success`；最终扩展二进制只包含 `_NSPerformService`，不再引用 NSWorkspace 打开目录路径。

## 复制/剪切后粘贴权限修复

2026-07-20 用户实机报告使用 SwiftMenu 复制或剪切文件后，在另一目录粘贴会提示“没有访问输入的许可”。根因是 `selectedItemURLs()` 提供的动态沙盒权限只属于复制/剪切菜单动作；旧实现只把普通文件 URL 写入剪贴板，稍后的粘贴动作从路径重建 URL 后再异步传输，源权限与目标动作权限都可能在后台执行前失效。

新增 `Sources/SwiftMenuFinderSync/SecurityScopedBookmarks.swift`：复制/剪切动作在权限仍有效时为每个源 URL 创建 read-write security-scoped bookmark，以二进制 Property List 编码到自定义 pasteboard type；粘贴动作优先恢复该载荷，外部应用提供的普通文件 URL 也会在当前动作内转换为 scoped URL。传输引擎按项 `startAccessing`/`stopAccessing`，使跨菜单动作的源文件授权得以延续。后续实机验证表明，安全书签只能延续已有权限，不能为 Finder `targetedURL` 指向的普通目标目录凭空创建写权限，因此目标目录仍需静态文件访问 entitlement。

验证包括 24 项核心测试，以及真实 App Sandbox 两阶段安全书签探针：第一阶段创建书签，第二阶段移除原始 Home 权限并重新签名，仅保留 `app-sandbox` 与 `files.user-selected.read-write`，随后成功读取书签源文件并完成同卷移动。这证明书签适合延续源权限，但不代表普通目标目录获得写权限。

### 粘贴菜单显示修复

2026-07-20 用户实机报告：通过 SwiftMenu 复制或剪切后，到新目录右键看不到“粘贴”。共享配置实查确认 `enablePaste = true` 且菜单顺序包含 `paste`，排除用户关闭功能。根因是复制动作会写入系统 `public.file-url` 和 SwiftMenu 安全书签两种剪贴板类型，但旧菜单构造逻辑只检查 `public.file-url`。该类型在 Finder/沙盒重新读取时可能不可见，即使自定义安全书签载荷仍完整可用，菜单也会误判剪贴板没有文件。

新增 `FilePasteboardContents` 类型识别逻辑，菜单热路径只读取类型标识，同时接受 `public.file-url` 与 `com.aporightmenu.SwiftMenu.security-scoped-bookmarks`，不提前解析 URL 或书签。新增四项测试分别验证系统文件 URL、安全书签单独存在时显示粘贴，以及只有剪切标记、空剪贴板时不显示粘贴。完整 24 项测试、性能门禁、签名、ZIP 解包和 DMG 挂载验收均通过。

## 右键新建与目标目录权限修复

2026-07-20 用户继续报告右键“新建文件”同样提示没有目标目录权限。根因是 Finder Sync 的 `targetedURL()` 表示菜单上下文位置，但 Apple 文档没有承诺它像 `NSOpenPanel` 一样签发 Powerbox 动态权限；在无静态目录权限时，对该普通 URL 创建 security-scoped bookmark 也不会增加权限。

`Sources/SwiftMenuFinderSync/SwiftMenuFinderSync.entitlements` 已为 Developer ID 直装版恢复 Home-relative `/` 读写，并增加 absolute `/Volumes/` 读写，覆盖用户目录、本地外接盘和网络挂载卷。`scripts/build_and_package.sh` 与 `scripts/run_tests.sh` 均对两项值做硬性断言，防止最终签名漏带。新增 `Tests/SandboxFileAccessProbe.swift`，以扩展同等 App Sandbox entitlement 和 Apple Development 证书签名后，在项目目录实际完成原子创建、回读和删除，输出 `sandbox_directory_write=success`。最新 App、ZIP、DMG 的最终扩展签名均已确认包含这两项权限。

当前 `/Applications/SwiftMenu.app` 仍是旧安装，系统插件数据库显示它处于启用状态，实际签名中缺少上述两项目录权限；本轮没有擅自覆盖用户的 `/Applications`。用户测试修复时必须先用最新 DMG 替换该 App，再重启 Finder（或注销重新登录），否则 Finder 仍会运行旧扩展并复现原错误。

这是为当前 Developer ID 直装产品选择的可靠性取舍，不是 Mac App Store 最小权限方案。若未来需要上架或进一步最小化静态权限，应把 Finder Sync 收敛为 UI 与请求转发层，由按需、非沙盒的受信辅助进程执行文件操作，并校验调用方签名、操作范围和路径。

## Logo 重设计探索

2026-07-20 使用内置 ImageGen 生成了六个互不覆盖的预览方案，项目现有 Logo 尚未替换：1）光标与菜单合体；2）雨燕与菜单行；3）闪光光标与按需出现的菜单；4）羽叶、菜单行与光标；5）双菜单构成的 S 形负空间；6）三层菜单窗格与光标缺口。当前设计判断：方案 3 最贴近“润物细无声的按需增强”，方案 1 产品识别最直接，方案 4 最能表达轻量低占用；待用户选择编号后再做小尺寸、单色、深浅色和最终 App Icon 精修。

用户随后明确要求取消颜色渐变，采用纯扁平风格。六个方案已分别重绘，并通过固定调色板量化为真实纯色 PNG，位于 `/Users/wample/.codex/generated_images/019f7d4c-3980-7f41-af6e-d3d22f840115/swiftmenu-flat-v2/`；每张只包含 3–5 个明确色值，不含渐变、阴影、发光或立体效果。项目内正式资源仍未替换，选定方案后应使用矢量路径重新绘制，以获得更好的边缘抗锯齿和全尺寸 App Icon 输出。

2026-07-20 用户正式选择方案 3。项目已用确定性 SVG 路径重绘正式母版 `assets/logo.svg`，保留光标、三行菜单和青色闪光，颜色固定为主背景 `#3532C8`、前景 `#FAFAF7`、强调 `#28D7D7`，圆角外部透明。README 使用由母版导出的 512 px `assets/logo.png`；App Icon 不再错误地让全部槽位复用同一张伪 PNG/JPEG 文件，而是提供 16、32、64、128、256、512、1024 px 对应资源。完整规范记录在 `Docs/LOGO_DESIGN.md`。验证已确认 10 个 Asset Catalog 槽位的文件、像素、RGBA 和透明圆角正确，`iconutil` 可成功合成为标准 `.icns`，16 px 至 512 px 明暗背景视觉预览可辨识；完整 24 项测试、LibreOffice 解析、性能门禁和 macOS 12 严格类型检查继续通过。

## CTA 与社区入口

2026-07-20 检查 `/Users/wample/coding/me/apo-video-extractor` 当前工作树、构建输出和 Git 历史后，未发现 CTA 组件或二维码文件；随后在同系列 `apo-*-onekey-startup` 项目中找到三套 SHA-256 完全一致的通用 CTA 原图，并以该公共版本作为可追溯来源。三张图已加入 `assets/cta/`，分别对应「阿坡RPA」公众号、作者个人微信和随喜支持；中文与英文 README 均以三栏形式展示。设置窗口新增「关于」页，提供与 SwiftMenu 场景匹配的 CTA 文案：关注公众号获取更新、发送暗号「SwiftMenu」加入交流群，以及自愿支持作者。初版只在 README 展示二维码；随后按下一段记录增加 App 内悬浮展示。

2026-07-20 根据用户要求，CTA 交互进一步参考同系列桌面启动器：三张二维码复制到主应用资源 `Sources/SwiftMenu/Resources/CTA/`，设置页任意 CTA 行在鼠标悬浮时使用原生 SwiftUI `popover` 展示对应二维码。三个入口共用一个弹层状态，避免快速跨行移动时出现高亮项与二维码不一致；鼠标从 CTA 行移入弹层时保持展示，离开两者 160 毫秒后收起。二维码通过静态缓存首次按需读取，没有常驻 Timer，不进入 Finder Sync 扩展。真实鼠标移动已验证公众号、微信切换和弹层驻留行为，视觉无裁切；设计说明见 `Docs/CTA_HOVER_DESIGN.md`。

## 用户偏好

- 默认使用中文交流与产出内容。
- Git commit message 使用中文。
- 每次对话的重要信息持续更新本文件。
