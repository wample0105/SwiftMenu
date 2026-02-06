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
    
    // 复活冷却时间，防止频繁调用 pluginkit
    private var lastReviveTime: Date?

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
    
    /// 启动 Extension 健康监控 (心跳监测版)
    private func startExtensionHealthMonitor() {
        // 每 5 秒检查一次心跳 (提高响应速度)
        extensionHealthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkExtensionHeartbeat()
        }
        
        // 立即检查一次
        checkExtensionHeartbeat()
    }
    
    /// 检查心跳文件
    private func checkExtensionHeartbeat() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.aporightmenu") else { return }
        let heartbeatFile = containerURL.appendingPathComponent("heartbeat")
        
        var isAlive = false
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: heartbeatFile.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                // 如果心跳在 10 秒内更新过，认为存活 (3秒心跳 + 缓冲)
                // 这样用户哪怕遇到 Crash，最慢 10 秒内也会尝试自动重启
                if Date().timeIntervalSince(modificationDate) < 10 {
                    isAlive = true
                } else {
                    print("⚠️ Watchdog: 心跳超时 (\(Date().timeIntervalSince(modificationDate))s ago)")
                }
            }
        } catch {
            print("⚠️ Watchdog: 无法读取心跳文件 (可能是首次启动)")
        }
        
        if !isAlive {
            reviveExtension()
        }
    }
    
    /// 复活扩展：通过插件系统重置
    private func reviveExtension() {
        // 简单的冷却机制，避免短时间内连续调用耗费 CPU
        if let last = lastReviveTime, Date().timeIntervalSince(last) < 10 {
            return
        }
        lastReviveTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔄 Watchdog: 尝试复活扩展...")
            let extensionID = "com.aporightmenu.SwiftMenu.finder"
            
            // 1. 先尝试让系统 "发现" 它 (query)
            let queryTask = Process()
            queryTask.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            queryTask.arguments = ["-m", "-p", "com.apple.FinderSync", "-i", extensionID]
            try? queryTask.run()
            queryTask.waitUntilExit()
            
            // 2. 强制启用 (use)
            let enableTask = Process()
            enableTask.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            enableTask.arguments = ["-e", "use", "-i", extensionID]
            try? enableTask.run()
            enableTask.waitUntilExit()
            
            print("✅ Watchdog: 复活指令已发送")
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
