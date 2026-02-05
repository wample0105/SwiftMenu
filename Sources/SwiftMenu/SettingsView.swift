//
//  SettingsView.swift
//  SwiftMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("常规", systemImage: "gearshape")
                }
            
            MenuOrderView()
                .tabItem {
                    Label("菜单排序", systemImage: "list.bullet")
                }
        }
        .frame(width: 500, height: 400)
        .padding(20)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // 🏷️ 顶部品牌区域 (简化版)
            HStack(spacing: 12) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftMenu")
                        .font(.system(size: 16, weight: .bold))
                    Text("Version 1.1.0")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Link("作者：阿坡", destination: URL(string: "https://github.com/wample0105")!)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Link("GitHub 项目主页", destination: URL(string: "https://github.com/wample0105/SwiftMenu")!)
                        .font(.system(size: 11))
                }
            }
            .padding(.bottom, 8)
            .overlay(Divider(), alignment: .bottom)
            
            // 1. 新建文件组
            HStack(alignment: .top, spacing: 16) {
                sectionLabel(title: "新建菜单", icon: "doc.badge.plus")
                    .frame(width: 90, alignment: .leading)
                
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
                    .frame(width: 90, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 24) {
                        checkbox("复制路径", isOn: $settings.enableCopyPath)
                        checkbox("终端打开", isOn: $settings.enableOpenInTerminal)
                    }
                    HStack(spacing: 24) {
                        checkbox("剪切", isOn: $settings.enableCut)
                        checkbox("复制", isOn: $settings.enableCopy)
                    }
                    HStack(spacing: 24) {
                        checkbox("粘贴", isOn: $settings.enablePaste)
                        Spacer()
                    }
                }
                Spacer()
            }
            
            Divider().opacity(0.5)
            
            // 3. 系统集成组
            HStack(alignment: .top, spacing: 16) {
                sectionLabel(title: "系统集成", icon: "gearshape.2")
                    .frame(width: 90, alignment: .leading)
                
                Toggle(isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0; setLaunchAtLogin($0) }
                )) {
                    Text("开机自启")
                        .font(.system(size: 13))
                }
                .toggleStyle(.checkbox)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // 助手组件
    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(.blue)
            Text(title).fontWeight(.semibold).foregroundColor(.secondary)
        }
    }
    
    private func checkbox(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn).toggleStyle(.checkbox).frame(width: 100, alignment: .leading)
    }
    
    // 设置开机启动
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("设置开机启动失败: \(error)")
            }
        }
    }
}

// MARK: - Menu Order Tab
struct MenuOrderView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("拖拽调整右键菜单顺序：")
                .font(.headline)
                .padding(.top)
            
            List {
                ForEach(settings.menuOrder, id: \.self) { key in
                    HStack {
                        // 拖拽手柄暗示
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.system(size: 10))
                        
                        // 功能图标 (与 Finder 菜单保持一致)
                        Image(systemName: iconName(for: key))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text(displayName(for: key))
                        Spacer()
                        if !isEnabled(for: key) {
                            Text("(已禁用)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveItem)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .cornerRadius(8)
            
            Text("提示：此顺序将即时应用到 Finder 右键菜单中。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        var order = settings.menuOrder
        order.move(fromOffsets: source, toOffset: destination)
        settings.menuOrder = order
    }
    
    private func displayName(for key: String) -> String {
        switch key {
        case "newFile": return "新建文件 (子菜单)"
        case "copyPath": return "复制路径"
        case "openInTerminal": return "在终端打开"
        case "cut": return "剪切"
        case "copy": return "复制"
        case "paste": return "粘贴"
        default: return key
        }
    }
    
    private func iconName(for key: String) -> String {
        switch key {
        case "newFile": return "doc.badge.plus"
        case "copyPath": return "doc.on.clipboard"
        case "openInTerminal": return "terminal"
        case "cut": return "scissors"
        case "copy": return "doc.on.doc"
        case "paste": return "doc.on.clipboard.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func isEnabled(for key: String) -> Bool {
        switch key {
        case "newFile": return settings.enableNewTXT || settings.enableNewWord || settings.enableNewExcel || settings.enableNewPPT || settings.enableNewMarkdown
        case "copyPath": return settings.enableCopyPath
        case "openInTerminal": return settings.enableOpenInTerminal
        case "cut": return settings.enableCut
        case "copy": return settings.enableCopy
        case "paste": return settings.enablePaste
        default: return true
        }
    }
}

#Preview {
    SettingsView()
}
