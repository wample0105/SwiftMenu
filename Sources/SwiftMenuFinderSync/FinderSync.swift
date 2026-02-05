import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    var myFolderURL: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths.first!)
    }()

    override init() {
        super.init()
        
        // 始终启用扩展，监控用户主目录和外部卷
        setupDirectoryMonitoring()
    }
    
    private func setupDirectoryMonitoring() {
        let finderSync = FIFinderSyncController.default()
        
        var urls = Set<URL>()
        
        // 获取真实的用户主目录
        var realHomeDir = NSHomeDirectory()
        if let pw = getpwuid(getuid()) {
            realHomeDir = String(cString: pw.pointee.pw_dir)
        }
        let home = URL(fileURLWithPath: realHomeDir)
        
        urls.insert(home)
        urls.insert(URL(fileURLWithPath: "/Volumes"))
        
        finderSync.directoryURLs = urls
        print("✅ FinderSync: 扩展已启用，监控目录：\(urls)")
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
        // 创建菜单
        let menu = NSMenu(title: "")
        
        // 检查设置（需要先修复 Target Membership）
        let settings = AppSettings.shared
        
        // 如果是在文件上右键
        if menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems {
            
            // 根据用户自定义顺序添加菜单项
            for key in settings.menuOrder {
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
                    if settings.enableCut {
                        let item = menu.addItem(withTitle: "剪切", action: #selector(cutFiles(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "scissors", accessibilityDescription: "剪切") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                case "copy":
                    if settings.enableCopy {
                        let item = menu.addItem(withTitle: "复制", action: #selector(copyFiles(_:)), keyEquivalent: "")
                        if let icon = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制") {
                            item.image = icon
                        }
                        item.target = self
                    }
                    
                case "paste":
                    if settings.enablePaste {
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
        }
        
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
        for url in urls {
            let destinationURL = targetFolder.appendingPathComponent(url.lastPathComponent)
            
            do {
                if isCut {
                    try fileManager.moveItem(at: url, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: url, to: destinationURL)
                }
            } catch {
                showDebugAlert(title: isCut ? "移动失败" : "复制失败", 
                             message: "无法\(isCut ? "移动" : "复制")\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // 剪切完成后清除剪切标记
        if isCut {
            pasteboard.clearContents()
        }
    }
}
