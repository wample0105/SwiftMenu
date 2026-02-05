//
//  AppDelegate.swift
//  SwiftMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import Cocoa
import SwiftUI
import FinderSync

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var statusItem: NSStatusItem?
    
    // Extension 健康检查定时器
    private var extensionHealthTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 SwiftMenu: applicationDidFinishLaunching")
        
        // 🔥 关键：使用 accessory 模式，主程序不显示在 Dock，但保持后台运行
        // 这样即使用户关闭设置窗口，主程序仍然运行，Extension 也会保持活跃
        NSApp.setActivationPolicy(.accessory)
        
        // 设置菜单栏图标
        setupStatusBar()
        
        // 每次启动都显示设置窗口
        showSettings()
        
        // 🔥 关键：定期检查 Extension 状态，必要时触发重新加载
        startExtensionHealthMonitor()
        
        // 禁用自动终止，保持主程序常驻
        ProcessInfo.processInfo.disableAutomaticTermination("SwiftMenu Main App")
        ProcessInfo.processInfo.disableSuddenTermination()
    }
    
    /// 启动 Extension 健康监控
    private func startExtensionHealthMonitor() {
        // 每 5 分钟检查一次 Extension 状态
        extensionHealthTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkExtensionHealth()
        }
        
        // 立即检查一次
        checkExtensionHealth()
    }
    
    /// 检查 Extension 是否正常运行
    private func checkExtensionHealth() {
        // 使用 pluginkit 检查 Extension 是否启用
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = ["-m", "-p", "com.apple.FinderSync"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 检查我们的 Extension 是否在列表中且已启用（前面有 +）
                let isEnabled = output.contains("+ ") && output.contains("com.aporightmenu")
                
                if isEnabled {
                    print("✅ Extension 健康检查：正常运行")
                } else {
                    print("⚠️ Extension 健康检查：未启用或未运行")
                    // 尝试触发 Extension 重新加载
                    triggerExtensionReload()
                }
            }
        } catch {
            print("❌ Extension 健康检查失败: \(error)")
        }
    }
    
    /// 触发 Extension 重新加载
    private func triggerExtensionReload() {
        // 方法1：刷新 Finder Sync Controller 目录
        // 这会触发系统重新加载 Extension
        let finderSync = FIFinderSyncController.default()
        let currentDirs = finderSync.directoryURLs
        finderSync.directoryURLs = Set<URL>()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finderSync.directoryURLs = currentDirs
            print("🔄 已触发 Extension 重新加载")
        }
    }

    private func setupStatusBar() {
        print("🎨 SwiftMenu: Setting up status bar...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // 创建组合图标：鼠标指针 + 文档
            let compositeIcon = createCompositeIcon()
            compositeIcon.isTemplate = true
            button.image = compositeIcon
            print("✅ SwiftMenu: 菜单栏组合图标已设置")
        }
        
        // 创建菜单
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "关于 SwiftMenu", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // 创建菜单栏图标：加载生成的资源文件
    private func createCompositeIcon() -> NSImage {
        // 使用生成的专用菜单栏图标（已通过脚本完美抠图并转为模板）
        if let icon = NSImage(named: "StatusBarIcon") {
            // 确保设置为模板，这样系统会自动处理颜色
            icon.isTemplate = true
            return icon
        }
        
        // 兜底方案
        if let fallback = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil) {
            return fallback
        }
        
        return NSImage(size: NSSize(width: 18, height: 18))
    }

    @objc func showSettings() {
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 如果窗口已经存在，直接显示
        if let existingWindow = self.window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // 如果窗口不存在（被释放了或从未创建），创建一个新的
        // 🔒 严格匹配 UI 设计尺寸 500x380
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.title = "SwiftMenu"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        
        // 使用 NSHostingController 托管 SwiftUI 视图
        newWindow.contentViewController = NSHostingController(rootView: SettingsView())
        
        // 关键：关闭时不要释放窗口对象，这样下次可以直接复用
        // 或者：如果释放了，上面的 if let check 会失败，然后重新创建，这也很安全
        newWindow.isReleasedWhenClosed = false 
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    // 处理点击 Dock 图标
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
    }


    @objc func showAbout() {
        // 先激活应用，确保关于窗口能即时弹到最前
        NSApp.activate(ignoringOtherApps: true)
        
        let credits = NSMutableAttributedString(string: "Design & Code by ", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
        ])
        
        let authorLink = NSAttributedString(string: "阿坡", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .link: URL(string: "https://github.com/wample0105")!,
            .foregroundColor: NSColor.linkColor
        ])
        
        credits.append(authorLink)
        credits.append(NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
        
        let link = NSAttributedString(string: "https://github.com/wample0105/SwiftMenu", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .link: URL(string: "https://github.com/wample0105/SwiftMenu")!,
            .foregroundColor: NSColor.linkColor
        ])
        
        credits.append(link)

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationVersion: "1.1.0"
        ])
    }

    @objc func terminateApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 清理代码
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
