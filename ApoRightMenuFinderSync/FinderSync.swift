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
        let settings = AppSettings.shared
        if !settings.extensionEnabled {
             NSLog("Extension disabled by user settings")
             return
        }

        // 🟢 现代写法：设置通过 Controller 监控的目录
        let finderSync = FIFinderSyncController.default()
        
        // 监控 Documents 目录和 桌面
        var urls = Set<URL>()
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
             urls.insert(docs)
        }
        if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
             urls.insert(desktop)
        }
        
        finderSync.directoryURLs = urls
        
        // 设置徽标通知（可选）
        // finderSync.setBadgeImage(..., label: ..., forBadgeIdentifier: "myBadge")
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
                item.tag = 1 // Tag 1 = TXT
            }
            if settings.enableNewWord {
                let item = newFileMenu.addItem(withTitle: "新建 Word 文档 (.docx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                item.tag = 2 // Tag 2 = Word
            }
            if settings.enableNewExcel {
                let item = newFileMenu.addItem(withTitle: "新建 Excel 表格 (.xlsx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                item.tag = 3 // Tag 3 = Excel
            }
             if settings.enableNewPPT {
                let item = newFileMenu.addItem(withTitle: "新建 PPT 演示文稿 (.pptx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                item.tag = 4 // Tag 4 = PPT
            }
             if settings.enableNewMarkdown {
                let item = newFileMenu.addItem(withTitle: "新建 Markdown 文件 (.md)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                item.tag = 5 // Tag 5 = Markdown
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
                menu.addItem(withTitle: "📋 复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
            }
            
            if settings.enableOpenInTerminal {
                menu.addItem(withTitle: "💻 在终端打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
            }
            
            if settings.enableMoveToTrash {
                menu.addItem(withTitle: "🗑️ 移到废纸篓", action: #selector(moveToTrash(_:)), keyEquivalent: "")
            }
        }
        
        return menu
    }
    
    // MARK: - Actions

    @objc func createNewFile(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        
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
        
        // 简单的重名处理逻辑
        var fileURL = target.appendingPathComponent("\(fileName).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = target.appendingPathComponent("\(fileName) \(counter).\(ext)")
            counter += 1
        }
        
        // 创建空文件
        let success = FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        
        if success {
            NSLog("File created at: \(fileURL.path)")
        } else {
            NSLog("Failed to create file")
        }
    }

    @objc func copyPath(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().selectedItemURLs()?.first ?? FIFinderSyncController.default().targetedURL() else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(target.path, forType: .string)
    }

    @objc func openInTerminal(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        
        NSWorkspace.shared.open([target], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
    
    @objc func moveToTrash(_ sender: AnyObject?) {
        guard let targets = FIFinderSyncController.default().selectedItemURLs() else { return }
        
        for url in targets {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}
