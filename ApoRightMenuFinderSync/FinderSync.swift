import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    var myFolderURL: URL = {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths.first!)
    }()

    override init() {
        super.init()
        
        // 🟢 修复 AppSettings 访问权限后，这里就能用了
        // 记得一定要在右侧把 Target Membership 勾选上！
//        let settings = AppSettings.shared
//        if !settings.extensionEnabled {
//             return
//        }

        // 🟢 现代写法：设置通过 Controller 监控的目录
        let finderSync = FIFinderSyncController.default()
        
        // 🟢 最终方案：监控 "用户主目录" 和 "Volumes"
        // 这是实现 "类 Windows 全局菜单" 的唯一标准方式。
        // 虽然 node_modules 文件多，但因为我们没有实现 "徽标 (Badge)" 逻辑，
        // 仅仅是菜单项，性能消耗极低，理论上是不会崩溃的。
        // 之前的崩溃大概率是 Xcode 调试产生的 "僵尸进程冲突"。
        var urls = Set<URL>()
        
        // 获取真实的 /Users/用户名 目录
        var realHomeDir = NSHomeDirectory()
        if let pw = getpwuid(getuid()) {
            realHomeDir = String(cString: pw.pointee.pw_dir)
        }
        let home = URL(fileURLWithPath: realHomeDir)
        
        urls.insert(home)
        urls.insert(URL(fileURLWithPath: "/Volumes"))
        
        finderSync.directoryURLs = urls
    }
    class DebugLogger {
        static func log(_ message: String) {
            let logFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("ApoRightMenu_Debug.txt")
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
        return "ApoRightMenu"
    }

    override var toolbarItemToolTip: String {
        return "ApoRightMenu Finder Extension"
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
            
            // --- 1. 新建文件子菜单 ---
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
                let subMenuItem = menu.addItem(withTitle: "📄 新建...", action: nil, keyEquivalent: "")
                menu.setSubmenu(newFileMenu, for: subMenuItem)
            }
            
            // 分隔线
            if !newFileMenu.items.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }

            // --- 2. 实用工具 ---
            if settings.enableCopyPath {
                let item = menu.addItem(withTitle: "📋 复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
                item.target = self
            }
            
            if settings.enableOpenInTerminal {
                let item = menu.addItem(withTitle: "💻 在终端打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
                item.target = self
            }
            
            if settings.enableMoveToTrash {
                let item = menu.addItem(withTitle: "🗑️ 移到废纸篓", action: #selector(moveToTrash(_:)), keyEquivalent: "")
                item.target = self
            }
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
    
    @objc func moveToTrash(_ sender: AnyObject?) {
        guard let targets = FIFinderSyncController.default().selectedItemURLs() else { return }
        
        for url in targets {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}
