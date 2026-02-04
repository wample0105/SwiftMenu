//
//  AppDelegate.swift
//  ApoRightMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 创建设置窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ApoRightMenu 设置"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 插入代码以在终止时清除
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
