import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    // 缓存配置，避免每次菜单弹出由于 IO 读取导致卡顿
    // 这是大厂保持菜单流畅的关键
    private let settings = AppSettings.shared
    
    override init() {
        super.init()
        
        // 仅监控用户主目录（最轻量级监控）
        // ⚠️ 必须使用 getpwuid 获取真实 Home 目录，不能用 FileManager (它返回的是沙盒路径)
        var realHomeDir = NSHomeDirectory()
        if let pw = getpwuid(getuid()) {
            if let homeDir = pw.pointee.pw_dir {
                realHomeDir = String(cString: homeDir)
            }
        }
        let homeURL = URL(fileURLWithPath: realHomeDir)
        FIFinderSyncController.default().directoryURLs = [homeURL]
        
        // 监听配置变化通知（避免轮询 Defaults）
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        
        NSLog("✅ FinderSync: Lightweight init complete, monitoring: \(homeURL.path)")
    }
    
    @objc func settingsChanged() {
        // 配置变了才刷新，否则完全静默
        // 可以在这里重新加载缓存的配置值
    }
    
    // 移除所有 KeepAlive/Watchdog 代码
    // 只有做得足够轻，系统才不会杀你
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    class DebugLogger {
        static func log(_ message: String) {
            let logFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("SwiftMenu_Debug.txt")
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            let entry = "[\(timestamp)] \(message)\n"
            
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(entry.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? entry.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Menu and Toolbar Item Support

    override var toolbarItemName: String {
        return "SwiftMenu"
    }

    override var toolbarItemToolTip: String {
        return "SwiftMenu Finder Extension"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // 创建菜单 (使用 lazy var 或缓存会更好，但 NSMenu 比较轻量，暂时保持)
        let menu = NSMenu(title: "")
        
        // 检查设置
        let settings = AppSettings.shared
        
        // 1. 快速检查：如果不在 Item 或 Container 上，直接返回空，避免后续计算
        if menuKind != .contextualMenuForContainer && menuKind != .contextualMenuForItems {
            return menu
        }
        
        // 2. 获取选中项 (这是一个相对轻量的 Finder Sync API)
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let hasSelectedFiles = !selectedItems.isEmpty
        
        // 3. 优化剪贴板读取：只在用户启用了粘贴功能时才读取，且只读取类型
        var clipboardHasFiles = false
        if settings.enablePaste {
            // 使用 types 预检查，比 readObjects 更快
            if let types = NSPasteboard.general.types, types.contains(.fileURL) {
                clipboardHasFiles = true
            }
        }
        

        // 🔥 关键修复：直接从 UserDefaults 读取菜单顺序，而不是使用 AppSettings 的缓存
        // 因为 AppSettings 是单例，在多进程环境下（主App修改，Extension读取）存储属性不会自动更新
        let userDefaults = UserDefaults(suiteName: "group.com.aporightmenu")
        let menuOrder = userDefaults?.array(forKey: "menuOrder") as? [String] ?? ["newFile", "copy", "cut", "paste", "copyPath", "openInTerminal"]
        
        // 根据顺序添加菜单项
        for key in menuOrder {
            switch key {
                case "newFile":
                    // 新建文件子菜单
                    let newFileMenu = NSMenu(title: "新建文件")
                    
                    if settings.enableNewTXT {
                        let item = newFileMenu.addItem(withTitle: "新建文本文档 (.txt)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 1
                        item.target = self
                    }
                    if settings.enableNewWord {
                        let item = newFileMenu.addItem(withTitle: "新建 Word 文档 (.docx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 2
                        item.target = self
                    }
                    if settings.enableNewExcel {
                        let item = newFileMenu.addItem(withTitle: "新建 Excel 表格 (.xlsx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 3
                        item.target = self
                    }
                    if settings.enableNewPPT {
                        let item = newFileMenu.addItem(withTitle: "新建 PPT 演示文稿 (.pptx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 4
                        item.target = self
                    }
                    if settings.enableNewMarkdown {
                        let item = newFileMenu.addItem(withTitle: "新建 Markdown 文件 (.md)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 5
                        item.target = self
                    }

                    // 只有当有子菜单项时才添加主菜单
                    if !newFileMenu.items.isEmpty {
                        let subMenuItem = NSMenuItem(title: "新建...", action: nil, keyEquivalent: "")
                        // 使用 SF Symbols 图标（macOS 原生风格）
                        if let icon = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件") {
                            subMenuItem.image = icon
                        }
                        menu.addItem(subMenuItem)
                        menu.setSubmenu(newFileMenu, for: subMenuItem)
                    }
                    
                case "copyPath":
                    if settings.enableCopyPath {
                        let item = menu.addItem(withTitle: "复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "复制路径") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                case "openInTerminal":
                    if settings.enableOpenInTerminal {
                        let item = menu.addItem(withTitle: "在终端打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: "在终端打开") {
                            item.image = icon
                        }
                        item.target = self
                    }
                                   case "cut":
                    // Windows风格：只有选中文件时才显示剪切
                    // 必须是在项目上右键 (.contextualMenuForItems)
                    if settings.enableCut && hasSelectedFiles && menuKind == .contextualMenuForItems {
                        let item = menu.addItem(withTitle: "剪切", action: #selector(cutFiles(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "scissors", accessibilityDescription: "剪切") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                case "copy":
                    // Windows风格：只有选中文件时才显示复制
                    // 必须是在项目上右键 (.contextualMenuForItems)
                    if settings.enableCopy && hasSelectedFiles && menuKind == .contextualMenuForItems {
                        let item = menu.addItem(withTitle: "复制", action: #selector(copyFiles(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                case "paste":
                    // Windows风格：只有剪贴板有文件时才显示粘贴
                    if settings.enablePaste && clipboardHasFiles {
                        let item = menu.addItem(withTitle: "粘贴", action: #selector(pasteFiles(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "粘贴") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                default:
                    break
                }
            }
            
            
            // 移到废纸篓功能已移除（原生菜单已提供）
        
        return menu
    }
    
    // MARK: - Actions

    // MARK: - Actions

    // 🟢 辅助方法：弹窗提示 (用于调试，生产环境可按需移除或保留为错误提示)
    func showDebugAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func createNewFile(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL() else {
            showDebugAlert(title: "错误", message: "无法获取当前路径 (Targeted URL is nil)")
            return
        }
        
        // 智能判断：如果是文件，则获取其父目录
        var targetFolder = target
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                targetFolder = target.deletingLastPathComponent()
            }
        }
        
        var fileName = "新建文件"
        var ext = "txt"
        
        switch sender.tag {
        case 1: fileName = "新建文本文档"; ext = "txt"
        case 2: fileName = "新建 Word 文档"; ext = "docx"
        case 3: fileName = "新建 Excel 表格"; ext = "xlsx"
        case 4: fileName = "新建 PPT 演示文稿"; ext = "pptx"
        case 5: fileName = "新建 Markdown 文件"; ext = "md"
        default: break
        }
        
        // 重名处理
        var fileURL = targetFolder.appendingPathComponent("\(fileName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = targetFolder.appendingPathComponent("\(fileName) \(counter).\(ext)")
            counter += 1
        }
        
        // 尝试创建
        do {
             if !FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil) {
                 // 再次尝试写入空字串
                 try "".write(to: fileURL, atomically: true, encoding: .utf8)
             }
             // 成功: 不弹窗，保持静默体验
        } catch {
            showDebugAlert(title: "创建失败", message: "无法创建文件：\(error.localizedDescription)\n路径：\(fileURL.path)")
        }
    }

    @objc func copyPath(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().selectedItemURLs()?.first ?? FIFinderSyncController.default().targetedURL() else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(target.path, forType: .string)
    }

    @objc func openInTerminal(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().targetedURL() else {
             showDebugAlert(title: "错误", message: "无法获取目标路径")
             return
        }
        
        var targetPath = target.path
        // 如果是文件，获取父目录
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir) {
            if !isDir.boolValue {
                targetPath = target.deletingLastPathComponent().path
            }
        }
        
        // 使用 Process 执行 open 命令（最接近原生实现，无需 AppleScript 权限）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", targetPath]
        
        do {
            try process.run()
        } catch {
            showDebugAlert(title: "无法打开终端", message: "错误：\(error.localizedDescription)")
        }
    }
    
    // MARK: - Cut/Copy/Paste Actions
    
    @objc func cutFiles(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        
        // 设置剪切标记（使用 macOS 原生的剪切标记）
        pasteboard.setData(Data([1]), forType: NSPasteboard.PasteboardType("com.apple.finder.node.cut"))
    }
    
    @objc func copyFiles(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }
    
    @objc func pasteFiles(_ sender: AnyObject?) {
        guard let targetURL = FIFinderSyncController.default().targetedURL() else { return }
        
        let pasteboard = NSPasteboard.general
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else { return }
        
        // 检查是否是剪切操作
        let isCut = pasteboard.data(forType: NSPasteboard.PasteboardType("com.apple.finder.node.cut")) != nil
        
        // 确定目标文件夹
        var targetFolder = targetURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                targetFolder = targetURL.deletingLastPathComponent()
            }
        }
        
        // 执行复制或移动
        let fileManager = FileManager.default
        var conflictChoice: Int? = nil // 记住用户的选择：0=替换, 1=跳过, 2=保留两者
        
        for url in urls {
            var destinationURL = targetFolder.appendingPathComponent(url.lastPathComponent)
            
            // 🛑 关键修复：检查源路径是否等于目标路径（原地复制）
            if url.path == destinationURL.path {
                // 如果是原地复制，强制重命名（生成副本），不询问替换（否则会删除源文件）
                destinationURL = generateUniqueURL(for: destinationURL)
            } else if fileManager.fileExists(atPath: destinationURL.path) {
                // 目标存在且不是源文件本身：正常的冲突处理
                if conflictChoice == nil {
                    let semaphore = DispatchSemaphore(value: 0)
                    var userChoice: Int = 1 // 默认跳过
                    
                    DispatchQueue.main.async {
                        // 激活应用以将弹窗显示在最前面
                        NSApp.activate(ignoringOtherApps: true)
                        
                        let alert = NSAlert()
                        alert.messageText = "文件已存在"
                        alert.informativeText = "「\(url.lastPathComponent)」已存在于目标位置。您想如何处理？"
                        alert.addButton(withTitle: "替换")
                        alert.addButton(withTitle: "跳过")
                        alert.addButton(withTitle: "保留两者")
                        alert.alertStyle = .warning
                        
                        // 设置窗口层级为浮动窗口，确保显示在所有窗口之上（包括全屏Finder）
                        alert.window.level = .floating
                        
                        let response = alert.runModal()
                        userChoice = response.rawValue - 1000
                        semaphore.signal()
                    }
                    
                    // 等待用户响应
                    semaphore.wait()
                    conflictChoice = userChoice
                }
                
                // 根据用户选择处理
                switch conflictChoice {
                case 0: // 替换
                    // 删除目标文件（注意：前面已经排除了源=目标的情况）
                    try? fileManager.removeItem(at: destinationURL)
                    
                case 1: // 跳过
                    continue
                    
                case 2: // 保留两者（重命名）
                    destinationURL = generateUniqueURL(for: destinationURL)
                    
                default:
                    continue
                }
            }
            
            // 执行实际的复制或移动操作
            do {
                if isCut {
                    try fileManager.moveItem(at: url, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: url, to: destinationURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showDebugAlert(title: isCut ? "移动失败" : "复制失败", 
                                 message: "无法\(isCut ? "移动" : "复制")\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // 剪切完成后清除剪切标记
        if isCut {
            pasteboard.clearContents()
        }
    }
    
    // 生成不重名的文件URL（添加数字后缀）
    private func generateUniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL = url
        
        // 修改重命名逻辑：如果是 "xxx copy.txt" 这种风格
        // 这里简单使用 "xxx 1.txt", "xxx 2.txt"
        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = ext.isEmpty ? "\(filename) \(counter)" : "\(filename) \(counter).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }
        
        return newURL
    }
    

}
