//
//  SettingsView.swift
//  ApoRightMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("RightMenu")
                        .font(.system(size: 24, weight: .bold))
                    Text("macOS 右键菜单增强工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 开发者信息
                Text("阿坡")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 新建文件菜单
                    settingsSection(title: "新建文件菜单", icon: "doc.badge.plus") {
                        Toggle("新建 TXT 文档", isOn: Binding(
                            get: { settings.enableNewTXT },
                            set: { settings.enableNewTXT = $0 }
                        ))
                        Toggle("新建 Word 文档", isOn: Binding(
                            get: { settings.enableNewWord },
                            set: { settings.enableNewWord = $0 }
                        ))
                        Toggle("新建 Excel 表格", isOn: Binding(
                            get: { settings.enableNewExcel },
                            set: { settings.enableNewExcel = $0 }
                        ))
                        Toggle("新建 PPT 演示文稿", isOn: Binding(
                            get: { settings.enableNewPPT },
                            set: { settings.enableNewPPT = $0 }
                        ))
                        Toggle("新建 Markdown 文件", isOn: Binding(
                            get: { settings.enableNewMarkdown },
                            set: { settings.enableNewMarkdown = $0 }
                        ))
                    }
                    
                    // 文件操作菜单
                    settingsSection(title: "文件操作", icon: "doc.text") {
                        Toggle("复制文件路径", isOn: Binding(
                            get: { settings.enableCopyPath },
                            set: { settings.enableCopyPath = $0 }
                        ))
                        Toggle("在终端中打开", isOn: Binding(
                            get: { settings.enableOpenInTerminal },
                            set: { settings.enableOpenInTerminal = $0 }
                        ))
                    }
                    
                    // Extension 控制
                    settingsSection(title: "Finder 扩展", icon: "square.grid.3x3") {
                        Toggle("启用 Finder 扩展", isOn: Binding(
                            get: { settings.extensionEnabled },
                            set: { newValue in
                                settings.extensionEnabled = newValue
                                toggleExtension(newValue)
                            }
                        ))
                        
                        if !settings.extensionEnabled {
                            Text("Finder 扩展已禁用，右键菜单将不会显示")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // 开机启动
                    settingsSection(title: "启动设置", icon: "power") {
                        Toggle("开机自动启动", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { newValue in
                                settings.launchAtLogin = newValue
                                setLaunchAtLogin(newValue)
                            }
                        ))
                        
                        Text("开启后，RightMenu 将在您登录 macOS 时自动运行")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // 底部信息
            HStack {
                Text("版本 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("© 2026 阿坡")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // 设置区块组件
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // 启用/停用 Finder Extension
    private func toggleExtension(_ enabled: Bool) {
        // 注意：需要在主应用中导入 FinderSync 框架
        // 这里暂时只是保存状态，实际激活需要用户在系统设置中操作
        print("Extension toggled to: \(enabled)")
    }
    
    // 设置开机启动
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用 SMAppService
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ 开机启动已启用")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ 开机启动已禁用")
                }
            } catch {
                print("❌ 设置开机启动失败: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 及更早版本：引导用户手动添加或暂时忽略
            print("⚠️ SMAppService 仅支持 macOS 13+")
        }
    }
}

#Preview {
    SettingsView()
}
