//
//  SettingsView.swift
//  SwiftMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import AppKit
import SwiftUI

enum SettingsTab: Hashable {
    case general
    case menuOrder
    case about
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("常规", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            MenuOrderView()
                .tabItem {
                    Label("菜单排序", systemImage: "list.bullet")
                }
                .tag(SettingsTab.menuOrder)

            AboutSettingsView()
                .tabItem {
                    Label("关于", systemImage: "person.crop.circle")
                }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: 500, height: 370)
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    @State private var hoveredCTA: CTAItem?
    @State private var presentedCTA: CTAItem?
    @State private var isPopoverHovered = false
    @State private var closeTask: Task<Void, Never>?

    private let projectURL = URL(string: "https://github.com/wample0105/SwiftMenu")!
    private let authorURL = URL(string: "https://github.com/wample0105")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("SwiftMenu")
                        .font(.system(size: 17, weight: .bold))
                    Text("让 Finder 右键菜单更顺手")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                ForEach(CTAItem.allCases) { item in
                    CTAHoverRow(
                        item: item,
                        isHovered: hoveredCTA == item || presentedCTA == item
                    ) { isHovering in
                        handleRowHover(item, isHovering: isHovering)
                    }
                }
            }
            .popover(item: $presentedCTA, arrowEdge: .trailing) { item in
                QRCodePopoverCard(item: item)
                    .id(item.id)
                    .onHover { isHovering in
                        isPopoverHovered = isHovering
                        if isHovering {
                            cancelPopoverClose()
                        } else {
                            schedulePopoverClose()
                        }
                    }
            }

            Divider()

            HStack(spacing: 16) {
                Link(destination: projectURL) {
                    Label("在 README 查看二维码", systemImage: "qrcode")
                }
                Link(destination: authorURL) {
                    Label("作者主页", systemImage: "person.crop.circle")
                }
                Spacer()
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding()
        .onDisappear {
            closeTask?.cancel()
        }
    }

    private func handleRowHover(_ item: CTAItem, isHovering: Bool) {
        if isHovering {
            cancelPopoverClose()
            hoveredCTA = item
            presentedCTA = item
        } else {
            if hoveredCTA == item {
                hoveredCTA = nil
            }
            schedulePopoverClose()
        }
    }

    private func cancelPopoverClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    private func schedulePopoverClose() {
        cancelPopoverClose()
        closeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled, hoveredCTA == nil, !isPopoverHovered else { return }
            presentedCTA = nil
        }
    }
}

private enum CTAItem: String, CaseIterable, Identifiable, Sendable {
    case officialAccount
    case wechat
    case donate

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .officialAccount: return "dot.radiowaves.left.and.right"
        case .wechat: return "person.2"
        case .donate: return "heart"
        }
    }

    var title: String {
        switch self {
        case .officialAccount: return "关注公众号「阿坡RPA」"
        case .wechat: return "添加作者「阿坡」"
        case .donate: return "请作者喝杯咖啡"
        }
    }

    var detail: String {
        switch self {
        case .officialAccount: return "获取 SwiftMenu 最新版本与实用工具"
        case .wechat: return "发送暗号「SwiftMenu」，加入专属交流群"
        case .donate: return "自愿打赏，感谢你对 SwiftMenu 的支持"
        }
    }

    var popoverTitle: String {
        switch self {
        case .officialAccount: return "关注公众号"
        case .wechat: return "加我微信"
        case .donate: return "随喜支持"
        }
    }

    var resourceName: String {
        switch self {
        case .officialAccount: return "apo-rpa-qrcode"
        case .wechat: return "apo-wechat-qrcode"
        case .donate: return "apo-donate-qrcode"
        }
    }
}

private struct CTAHoverRow: View {
    let item: CTAItem
    let isHovered: Bool
    let hoverChanged: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "qrcode")
                .font(.system(size: 12))
                .foregroundColor(isHovered ? .blue : .secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
        )
        .onHover(perform: hoverChanged)
        .accessibilityHint("鼠标悬浮可查看二维码")
    }
}

private struct QRCodePopoverCard: View {
    let item: CTAItem

    var body: some View {
        VStack(spacing: 9) {
            Label(item.popoverTitle, systemImage: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.blue)

            Group {
                if let qrCodeImage = QRCodeImageStore.image(for: item) {
                    Image(nsImage: qrCodeImage)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel("\(item.popoverTitle)二维码")
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 36))
                        Text("二维码资源缺失")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .frame(width: 164, height: 164)
            .padding(5)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 214)
    }
}

private enum QRCodeImageStore {
    private static let images: [CTAItem: NSImage] = {
        Dictionary(uniqueKeysWithValues: CTAItem.allCases.compactMap { item in
            guard let url = resourceURL(for: item), let image = NSImage(contentsOf: url) else {
                return nil
            }
            return (item, image)
        })
    }()

    static func image(for item: CTAItem) -> NSImage? {
        images[item]
    }

    private static func resourceURL(for item: CTAItem) -> URL? {
        let bundle = Bundle.main
        return bundle.url(forResource: item.resourceName, withExtension: "png", subdirectory: "CTA")
            ?? bundle.url(forResource: item.resourceName, withExtension: "png", subdirectory: "Resources/CTA")
            ?? bundle.url(forResource: item.resourceName, withExtension: "png")
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showsExtensionSettingsError = false
    
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
                    Text("Version \(appVersion)")
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
            
            // 3. 运行方式说明
            HStack(alignment: .top, spacing: 16) {
                sectionLabel(title: "运行方式", icon: "leaf")
                    .frame(width: 90, alignment: .leading)

                VStack(alignment: .leading, spacing: 7) {
                    Text("关闭设置窗口只退出主程序；Finder 扩展由 macOS 按需运行。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        if !Self.openFinderExtensionSettings() {
                            showsExtensionSettingsError = true
                        }
                    } label: {
                        Label("管理 Finder 扩展…", systemImage: "switch.2")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("前往系统设置启用或彻底停用 SwiftMenu Finder 扩展")
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .alert("无法打开系统设置", isPresented: $showsExtensionSettingsError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请手动打开“系统设置 → 通用 → 登录项与扩展”，然后管理 Finder 扩展。")
        }
    }

    private static func openFinderExtensionSettings() -> Bool {
        let workspace = NSWorkspace.shared
        let paneIdentifiers: [String]
        if #available(macOS 13.0, *) {
            paneIdentifiers = [
                "com.apple.LoginItems-Settings.extension",
                "com.apple.preference.extensions"
            ]
        } else {
            paneIdentifiers = ["com.apple.preference.extensions"]
        }

        for identifier in paneIdentifiers {
            guard let url = URL(string: "x-apple.systempreferences:\(identifier)") else { continue }
            if workspace.open(url) {
                return true
            }
        }

        let applicationPaths = [
            "/System/Applications/System Settings.app",
            "/System/Applications/System Preferences.app"
        ]
        for path in applicationPaths where FileManager.default.fileExists(atPath: path) {
            if workspace.open(URL(fileURLWithPath: path, isDirectory: true)) {
                return true
            }
        }
        return false
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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
