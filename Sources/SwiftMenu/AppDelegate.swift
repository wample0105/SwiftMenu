import AppKit
import os
import ServiceManagement

/// 主应用仅用于修改设置。Finder Sync 扩展由 macOS 独立管理，主应用无需常驻。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.registerDefaultsIfNeeded()
        removeLegacyHeartbeatFile()
        removeLegacyLoginItemIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭设置窗口后立即结束主进程，避免 SwiftUI/AppKit 常驻内存。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// 1.1.0 及以前可将主应用注册为登录项；新架构不再依赖常驻主进程。
    private func removeLegacyLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }
        let defaults = UserDefaults(suiteName: "group.com.aporightmenu") ?? .standard
        guard defaults.bool(forKey: "launchAtLogin") else { return }

        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            defaults.removeObject(forKey: "launchAtLogin")
        } catch {
            Logger(subsystem: "com.aporightmenu.SwiftMenu", category: "Migration")
                .error("Unable to remove legacy login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeLegacyHeartbeatFile() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.aporightmenu"
        ) else { return }

        let heartbeatURL = containerURL.appendingPathComponent("heartbeat")
        if FileManager.default.fileExists(atPath: heartbeatURL.path) {
            try? FileManager.default.removeItem(at: heartbeatURL)
        }
    }
}
