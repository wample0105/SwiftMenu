import Cocoa
import FinderSync

@MainActor
final class FinderSync: FIFinderSync {
    private let settings = AppSettings.shared
    private let transferEngine = FileTransferEngine()
    private let transferQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.aporightmenu.SwiftMenu.file-transfer"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private enum Icons {
        static let newFile = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件")
        static let copyPath = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "复制路径")
        static let terminal = NSImage(systemSymbolName: "terminal", accessibilityDescription: "在终端打开")
        static let cut = NSImage(systemSymbolName: "scissors", accessibilityDescription: "剪切")
        static let copy = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制")
        static let paste = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "粘贴")
    }

    private enum PasteboardTypes {
        static let cutMarker = NSPasteboard.PasteboardType("com.apple.finder.node.cut")
        static let securityScopedBookmarks = NSPasteboard.PasteboardType(
            FilePasteboardContents.securityScopedBookmarksTypeIdentifier
        )
    }
    
    override init() {
        super.init()
        
        // Finder Sync 只在注册目录中提供菜单。覆盖 Home 与 /Volumes，兼顾日常目录和挂载卷。
        var realHomeDir = NSHomeDirectory()
        if let pw = getpwuid(getuid()) {
            if let homeDir = pw.pointee.pw_dir {
                realHomeDir = String(cString: homeDir)
            }
        }
        let homeURL = URL(fileURLWithPath: realHomeDir)
        var monitoredURLs = [homeURL]
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        if FileManager.default.fileExists(atPath: volumesURL.path) {
            monitoredURLs.append(volumesURL)
        }
        FIFinderSyncController.default().directoryURLs = Set(monitoredURLs)
    }

    // MARK: - Menu and Toolbar Item Support

    override var toolbarItemName: String {
        return "SwiftMenu"
    }

    override var toolbarItemToolTip: String {
        return "SwiftMenu Finder Extension"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "cursorarrow.square", accessibilityDescription: "SwiftMenu")
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.autoenablesItems = false

        // 非右键菜单请求立即返回，避免任何配置或剪贴板读取。
        if menuKind != .contextualMenuForContainer && menuKind != .contextualMenuForItems {
            return menu
        }

        let configuration = settings.snapshot()

        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        let hasSelectedFiles = !selectedItems.isEmpty

        // 仅在启用粘贴时读取类型，不解析剪贴板中的 URL 对象。
        var clipboardHasFiles = false
        if configuration.enablePaste {
            // SwiftMenu 自己的安全书签载荷即使没有同时暴露 public.file-url，仍然可以粘贴。
            let typeIdentifiers = NSPasteboard.general.types?.map(\.rawValue) ?? []
            clipboardHasFiles = FilePasteboardContents.containsPasteableFiles(
                typeIdentifiers: typeIdentifiers
            )
        }
        
        // 根据顺序添加菜单项
        for key in configuration.menuOrder {
            switch key {
                case "newFile":
                    // 新建文件子菜单
                    let newFileMenu = NSMenu(title: "新建文件")
                    
                    if configuration.enableNewTXT {
                        let item = newFileMenu.addItem(withTitle: "新建文本文档 (.txt)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 1
                        item.target = self
                    }
                    if configuration.enableNewWord {
                        let item = newFileMenu.addItem(withTitle: "新建 Word 文档 (.docx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 2
                        item.target = self
                    }
                    if configuration.enableNewExcel {
                        let item = newFileMenu.addItem(withTitle: "新建 Excel 表格 (.xlsx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 3
                        item.target = self
                    }
                    if configuration.enableNewPPT {
                        let item = newFileMenu.addItem(withTitle: "新建 PPT 演示文稿 (.pptx)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 4
                        item.target = self
                    }
                    if configuration.enableNewMarkdown {
                        let item = newFileMenu.addItem(withTitle: "新建 Markdown 文件 (.md)", action: #selector(createNewFile(_:)), keyEquivalent: "")
                        item.tag = 5
                        item.target = self
                    }

                    // 只有当有子菜单项时才添加主菜单
                    if !newFileMenu.items.isEmpty {
                        let subMenuItem = NSMenuItem(title: "新建...", action: nil, keyEquivalent: "")
                        // 使用 SF Symbols 图标（macOS 原生风格）
                        subMenuItem.image = Icons.newFile
                        menu.addItem(subMenuItem)
                        menu.setSubmenu(newFileMenu, for: subMenuItem)
                    }
                    
                case "copyPath":
                    if configuration.enableCopyPath {
                        let item = menu.addItem(withTitle: "复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
                        item.image = Icons.copyPath
                        item.target = self
                    }
                    
                case "openInTerminal":
                    if configuration.enableOpenInTerminal {
                        let item = menu.addItem(withTitle: "在终端打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
                        item.image = Icons.terminal
                        item.target = self
                    }
                                   case "cut":
                    // Windows风格：只有选中文件时才显示剪切
                    // 必须是在项目上右键 (.contextualMenuForItems)
                    if configuration.enableCut && hasSelectedFiles && menuKind == .contextualMenuForItems {
                        let item = menu.addItem(withTitle: "剪切", action: #selector(cutFiles(_:)), keyEquivalent: "")
                        item.image = Icons.cut
                        item.target = self
                    }
                    
                case "copy":
                    // Windows风格：只有选中文件时才显示复制
                    // 必须是在项目上右键 (.contextualMenuForItems)
                    if configuration.enableCopy && hasSelectedFiles && menuKind == .contextualMenuForItems {
                        let item = menu.addItem(withTitle: "复制", action: #selector(copyFiles(_:)), keyEquivalent: "")
                        item.image = Icons.copy
                        item.target = self
                    }
                    
                case "paste":
                    // Windows风格：只有剪贴板有文件时才显示粘贴
                    if configuration.enablePaste && clipboardHasFiles {
                        let item = menu.addItem(withTitle: "粘贴", action: #selector(pasteFiles(_:)), keyEquivalent: "")
                        item.image = Icons.paste
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

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.window.level = .floating
        alert.runModal()
    }

    @objc func createNewFile(_ sender: NSMenuItem) {
        guard let target = FIFinderSyncController.default().targetedURL() else {
            Self.showAlert(title: "无法新建文件", message: "Finder 没有提供当前目录。")
            return
        }
        let fileTypeTag = sender.tag
        var targetFolder = target
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            targetFolder = target.deletingLastPathComponent()
        }

        let scopedTargetFolder: URL
        do {
            scopedTargetFolder = try SecurityScopedBookmarks.scopedURL(for: targetFolder)
        } catch {
            Self.showAlert(
                title: "无法新建文件",
                message: "未能取得目标目录权限：\(error.localizedDescription)"
            )
            return
        }

        transferQueue.addOperation {
            let didAccessTarget = scopedTargetFolder.startAccessingSecurityScopedResource()
            defer {
                if didAccessTarget {
                    scopedTargetFolder.stopAccessingSecurityScopedResource()
                }
            }

            let descriptor = Self.newFileDescriptor(for: fileTypeTag)
            var fileURL = scopedTargetFolder.appendingPathComponent("\(descriptor.name).\(descriptor.extensionName)")
            var counter = 1
            while FileManager.default.fileExists(atPath: fileURL.path) {
                fileURL = scopedTargetFolder.appendingPathComponent(
                    "\(descriptor.name) \(counter).\(descriptor.extensionName)"
                )
                counter += 1
            }

            do {
                try descriptor.contents.write(to: fileURL, options: .atomic)
            } catch {
                let message = "无法创建文件：\(error.localizedDescription)\n路径：\(fileURL.path)"
                DispatchQueue.main.async {
                    Self.showAlert(title: "创建失败", message: message)
                }
            }
        }
    }

    nonisolated private static func newFileDescriptor(
        for tag: Int
    ) -> (name: String, extensionName: String, contents: Data) {
        switch tag {
        case 2:
            return ("新建 Word 文档", "docx", OfficeDocumentFactory.documentData(for: .word))
        case 3:
            return ("新建 Excel 表格", "xlsx", OfficeDocumentFactory.documentData(for: .spreadsheet))
        case 4:
            return ("新建 PPT 演示文稿", "pptx", OfficeDocumentFactory.documentData(for: .presentation))
        case 5:
            return ("新建 Markdown 文件", "md", Data())
        default:
            return ("新建文本文档", "txt", Data())
        }
    }

    @objc func copyPath(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().selectedItemURLs()?.first ?? FIFinderSyncController.default().targetedURL() else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(target.path, forType: .string)
    }

    @objc func openInTerminal(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().targetedURL() else {
             Self.showAlert(title: "无法打开终端", message: "Finder 没有提供当前目录。")
             return
        }

        guard TerminalLauncher.open(target: target) else {
            Self.showAlert(
                title: "无法打开终端",
                message: "macOS 的“新建位于文件夹位置的终端窗口”服务不可用，请确认 Terminal.app 可正常使用。"
            )
            return
        }
    }
    
    // MARK: - Cut/Copy/Paste Actions
    
    @objc func cutFiles(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }

        Self.writeFileSelectionToPasteboard(urls, isCut: true)
    }
    
    @objc func copyFiles(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }

        Self.writeFileSelectionToPasteboard(urls, isCut: false)
    }
    
    @objc func pasteFiles(_ sender: AnyObject?) {
        guard let targetURL = FIFinderSyncController.default().targetedURL() else { return }

        let pasteboard = NSPasteboard.general
        let urls: [URL]
        do {
            if let payload = pasteboard.data(forType: PasteboardTypes.securityScopedBookmarks) {
                urls = try SecurityScopedBookmarks.resolvePayload(payload)
            } else {
                guard let pastedURLs = pasteboard.readObjects(
                    forClasses: [NSURL.self],
                    options: nil
                ) as? [URL], !pastedURLs.isEmpty else { return }
                urls = try SecurityScopedBookmarks.scopedURLs(for: pastedURLs)
            }
        } catch {
            Self.showAlert(
                title: "无法粘贴",
                message: "未能恢复源文件权限：\(error.localizedDescription)\n请重新复制或剪切后再试。"
            )
            return
        }

        let isCut = pasteboard.data(forType: PasteboardTypes.cutMarker) != nil
        let pasteboardChangeCount = pasteboard.changeCount

        var targetFolder = targetURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                targetFolder = targetURL.deletingLastPathComponent()
            }
        }

        let destinationFolder: URL
        do {
            destinationFolder = try SecurityScopedBookmarks.scopedURL(for: targetFolder)
        } catch {
            Self.showAlert(
                title: "无法粘贴",
                message: "未能取得目标目录权限：\(error.localizedDescription)"
            )
            return
        }
        let transferEngine = self.transferEngine
        let transferQueue = self.transferQueue
        transferQueue.addOperation {
            let hasConflict = transferEngine.hasConflict(
                sources: urls,
                destinationFolder: destinationFolder
            )
            DispatchQueue.main.async {
                let conflictPolicy: FileConflictPolicy
                if hasConflict {
                    guard let selectedPolicy = Self.askConflictPolicy(itemCount: urls.count) else { return }
                    conflictPolicy = selectedPolicy
                } else {
                    conflictPolicy = .keepBoth
                }

                Self.enqueueTransfer(
                    FileTransferRequest(
                        sources: urls,
                        destinationFolder: destinationFolder,
                        mode: isCut ? .move : .copy,
                        conflictPolicy: conflictPolicy
                    ),
                    using: transferEngine,
                    on: transferQueue,
                    isCut: isCut,
                    expectedItemCount: urls.count,
                    pasteboardChangeCount: pasteboardChangeCount
                )
            }
        }
    }

    private static func writeFileSelectionToPasteboard(_ urls: [URL], isCut: Bool) {
        let accessPayload: Data
        do {
            accessPayload = try SecurityScopedBookmarks.makePayload(for: urls)
        } catch {
            showAlert(
                title: isCut ? "无法剪切" : "无法复制",
                message: "未能保存源文件权限：\(error.localizedDescription)"
            )
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let wroteURLs = pasteboard.writeObjects(urls as [NSURL])
        let wroteAccessPayload = pasteboard.setData(
            accessPayload,
            forType: PasteboardTypes.securityScopedBookmarks
        )
        let wroteCutMarker = !isCut || pasteboard.setData(
            Data([1]),
            forType: PasteboardTypes.cutMarker
        )

        guard wroteURLs, wroteAccessPayload, wroteCutMarker else {
            showAlert(
                title: isCut ? "无法剪切" : "无法复制",
                message: "未能把文件信息写入系统剪贴板。"
            )
            return
        }
    }

    private static func enqueueTransfer(
        _ request: FileTransferRequest,
        using transferEngine: FileTransferEngine,
        on transferQueue: OperationQueue,
        isCut: Bool,
        expectedItemCount: Int,
        pasteboardChangeCount: Int
    ) {
        transferQueue.addOperation {
            let result = transferEngine.perform(request)

            DispatchQueue.main.async {
                if isCut,
                   result.completedCount == expectedItemCount,
                   result.skippedCount == 0,
                   result.failures.isEmpty,
                   NSPasteboard.general.changeCount == pasteboardChangeCount {
                    NSPasteboard.general.clearContents()
                }

                guard !result.failures.isEmpty else { return }
                let preview = result.failures.prefix(3).map {
                    "• \($0.source.lastPathComponent)：\($0.message)"
                }.joined(separator: "\n")
                let remainder = result.failures.count > 3
                    ? "\n另有 \(result.failures.count - 3) 项失败。"
                    : ""
                Self.showAlert(
                    title: isCut ? "部分文件移动失败" : "部分文件复制失败",
                    message: preview + remainder
                )
            }
        }
    }

    /// 冲突选择在主线程直接完成，随后所有文件 I/O 都转移到串行后台队列。
    private static func askConflictPolicy(itemCount: Int) -> FileConflictPolicy? {
        let alert = NSAlert()
        alert.messageText = "目标位置已有同名项目"
        alert.informativeText = itemCount == 1
            ? "请选择如何处理同名项目。"
            : "所选项目中存在同名项目。该选择将应用于本次操作。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "保留两者")
        alert.addButton(withTitle: "跳过")
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
        alert.window.level = .floating

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .keepBoth
        case .alertSecondButtonReturn:
            return .skip
        case .alertThirdButtonReturn:
            return .replace
        default:
            return nil
        }
    }
}
