//
//  SwiftMenuApp.swift
//  SwiftMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import SwiftUI

@main
struct SwiftMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        // 使用 Settings 场景替代 WindowGroup
        // 这样 SwiftUI 不会在启动时自动创建主窗口，避免与 AppDelegate 冲突
        // 同时这也会把 SettingsView 绑定到 macOS 的 "偏好设置..." 菜单项
        Settings {
            SettingsView()
                .frame(width: 500, height: 380)
        }
    }
}
