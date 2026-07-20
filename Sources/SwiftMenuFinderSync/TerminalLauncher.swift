import AppKit

/// 通过 macOS 自带的 Terminal 服务打开目录。
///
/// 这里有意不把目录 URL 作为 Launch Services 的“打开文档”参数传给 Terminal。
/// Finder Sync 运行在 App Sandbox 中，直接传递文件 URL 会让系统以扩展的沙盒权限
/// 再次校验目录，进而出现“SwiftMenu 没有权限打开此目录”。系统服务只接收路径文本，
/// 与 Finder 自带的“新建位于文件夹位置的终端窗口”走同一条入口。
enum TerminalLauncher {
    private static let serviceName = "New Terminal at Folder"
    private static let pasteboardName = NSPasteboard.Name(
        "com.aporightmenu.SwiftMenu.open-in-terminal"
    )

    static func folderURL(for target: URL, fileManager: FileManager = .default) -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return target
        }
        return target.deletingLastPathComponent()
    }

    @MainActor
    static func open(target: URL) -> Bool {
        let folder = folderURL(for: target)
        let pasteboard = NSPasteboard(name: pasteboardName)
        pasteboard.clearContents()
        guard pasteboard.setString(folder.path, forType: .string) else {
            return false
        }

        // NSPerformService 会同步读取 pasteboard；调用结束后立即清掉路径，避免残留。
        defer { pasteboard.clearContents() }
        return NSPerformService(serviceName, pasteboard)
    }
}
