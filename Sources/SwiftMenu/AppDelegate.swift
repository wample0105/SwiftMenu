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
    
    // 进程监听源
    private var processSource: DispatchSourceProcess?
    
    /// 启动 Extension 健康监控 (实时响应版)
    private func startExtensionHealthMonitor() {
        // 1. 立即尝试建立实时监听
        setupProcessMonitor()
        
        // 2. 保留一个低频轮询作为双保险（比如每30秒），防止监听失效或初次启动未找到进程
        extensionHealthTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.ensureExtensionAlive()
        }
    }
    
    /// 设置进程监听（Unix Signal 级别，毫秒级响应）
    private func setupProcessMonitor() {
        // 取消旧的监听
        processSource?.cancel()
        processSource = nil
        
        // 获取进程 PID
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "SwiftMenuFinderSync"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // pgrep 可能返回多行 PID（多个实例），我们只取第一个有效的
            let pids = output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            
            if let pid = pids.first {
                print("✅ Watchdog: 发现 \(pids.count) 个实例，锁定主 PID=[\(pid)] 开始监听...")
                
                // 创建进程监听源
                let source = DispatchSource.makeProcessSource(identifier: pid_t(pid), eventMask: .exit, queue: .main)
                
                source.setEventHandler { [weak self] in
                    print("⚠️ Watchdog: 收到进程退出信号 (PID \(pid))")
                    
                    // 进程退出了，无论如何都尝试复活一下，以防万一
                    self?.reviveExtension()
                    
                    // 延迟后重新建立监听
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.setupProcessMonitor()
                    }
                }
                
                source.resume()
                self.processSource = source
            } else {
                // pgrep 没报错但也没返回有效 PID
                print("⚠️ Watchdog: 未找到有效 PID，尝试复活...")
                reviveExtension()
                
                // 稍后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    if self?.processSource == nil {
                        self?.setupProcessMonitor()
                    }
                }
            }
        } catch {
            // pgrep 执行出错（通常意味着没找到进程，返回非0状态码）
            print("⚠️ Watchdog: 未检测到进程，正在复活...")
            reviveExtension()
            
            // 稍后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if self?.processSource == nil {
                    self?.setupProcessMonitor()
                }
            }
        }
    }
    
    /// 确保扩展存活（轮询用）
    private func ensureExtensionAlive() {
        // 如果没有建立监听，说明可能挂了
        if processSource == nil || processSource?.isCancelled == true {
             // 检查进程是否存在，不存在则复活
            checkAndRevive()
        }
    }
    
    private func checkAndRevive() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "SwiftMenuFinderSync"]
        try? task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            print("🕒 Watchdog (轮询): 发现扩展未运行，正在复活...")
            reviveExtension()
            // 复活后稍等片刻建立监听
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.setupProcessMonitor()
            }
        }
    }
    
    /// 复活扩展：强力重启模式
    private func reviveExtension() {
        let extensionID = "com.aporightmenu.SwiftMenu.finder"
        
        // 1. 先尝试让系统 "发现" 它 (query)
        let queryTask = Process()
        queryTask.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        queryTask.arguments = ["-m", "-p", "com.apple.FinderSync", "-i", extensionID]
        try? queryTask.run()
        queryTask.waitUntilExit()
        
        // 2. 强制启用 (use)
        // 注意：有些时候系统需要你先 ignore 再 use 才能触发重启，
        // 但太频繁的 ignore 可能会导致配置丢失。
        // 最稳妥的方法是反复发送 use 指令
        
        let enableTask = Process()
        enableTask.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        enableTask.arguments = ["-e", "use", "-i", extensionID]
        try? enableTask.run()
        enableTask.waitUntilExit()
        
        print("🔄 Watchdog: 已发送复活指令 (Force Enable)")
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
