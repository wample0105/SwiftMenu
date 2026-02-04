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
        VStack(spacing: 0) {
            // 🏷️ 顶部品牌区域
            HStack(spacing: 16) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("RightMenu")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("让 Mac 拥有更高效的右键菜单")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Version 1.0.0")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("© 2026 阿坡")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 🎛️ 核心设置区域
            VStack(spacing: 24) {
                // 1. 新建文件组
                HStack(alignment: .top, spacing: 16) {
                    sectionLabel(title: "新建菜单", icon: "doc.badge.plus")
                        .frame(width: 100, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 24) {
                            checkbox("TXT 文档", isOn: $settings.enableNewTXT)
                            checkbox("PPT 演示", isOn: $settings.enableNewPPT)
                        }
                        HStack(spacing: 24) {
                            checkbox("Word 文档", isOn: $settings.enableNewWord)
                            checkbox("Markdown", isOn: $settings.enableNewMarkdown)
                        }
                        HStack(spacing: 24) {
                            checkbox("Excel 表格", isOn: $settings.enableNewExcel)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.5)
                
                // 2. 文件操作组
                HStack(alignment: .top, spacing: 16) {
                    sectionLabel(title: "文件操作", icon: "folder.badge.gear")
                        .frame(width: 100, alignment: .leading)
                    
                    HStack(spacing: 24) {
                        checkbox("复制路径", isOn: $settings.enableCopyPath)
                        checkbox("终端打开", isOn: $settings.enableOpenInTerminal)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.5)
                
                // 3. 系统集成组 - 只保留开机自启
                HStack(alignment: .top, spacing: 16) {
                    sectionLabel(title: "系统集成", icon: "gearshape.2")
                        .frame(width: 100, alignment: .leading)
                    
                    Toggle(isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.launchAtLogin = $0; setLaunchAtLogin($0) }
                    )) {
                        Text("开机自启")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.checkbox)
                    .help("开启后，RightMenu 将在登录 macOS 时自动运行")
                    
                    Spacer()
                }
            }
            .padding(24)
            
            Spacer()
        }
        .frame(width: 500, height: 380) // 🔒 黄金比例紧凑尺寸
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // ✨ 辅助视图组件
    
    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(width: 110, alignment: .leading) // 固定左侧标签宽度，实现完美对齐
    }
    
    private func checkbox(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 13))
        }
        .toggleStyle(.checkbox)
        .frame(width: 100, alignment: .leading) // 固定选项宽度，实现网格感
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
