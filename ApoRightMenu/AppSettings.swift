//
//  AppSettings.swift
//  ApoRightMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // 使用 App Group 共享设置，让 Extension 也能读取
    private let userDefaults = UserDefaults(suiteName: "group.com.aporightmenu")
    
    // 新建文件菜单开关
    var enableNewTXT: Bool {
        get { return userDefaults?.bool(forKey: "enableNewTXT") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableNewTXT"); objectWillChange.send() }
    }
    
    var enableNewWord: Bool {
        get { return userDefaults?.bool(forKey: "enableNewWord") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableNewWord"); objectWillChange.send() }
    }
    
    var enableNewExcel: Bool {
        get { return userDefaults?.bool(forKey: "enableNewExcel") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableNewExcel"); objectWillChange.send() }
    }
    
    var enableNewPPT: Bool {
        get { return userDefaults?.bool(forKey: "enableNewPPT") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableNewPPT"); objectWillChange.send() }
    }
    
    var enableNewMarkdown: Bool {
        get { return userDefaults?.bool(forKey: "enableNewMarkdown") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableNewMarkdown"); objectWillChange.send() }
    }
    
    // 复制文件路径开关
    var enableCopyPath: Bool {
        get { return userDefaults?.bool(forKey: "enableCopyPath") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableCopyPath"); objectWillChange.send() }
    }
    
    // 在终端中打开开关
    var enableOpenInTerminal: Bool {
        get { return userDefaults?.bool(forKey: "enableOpenInTerminal") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableOpenInTerminal"); objectWillChange.send() }
    }
    
    // 移动到废纸篓开关
    var enableMoveToTrash: Bool {
        get { return userDefaults?.bool(forKey: "enableMoveToTrash") ?? true }
        set { userDefaults?.set(newValue, forKey: "enableMoveToTrash"); objectWillChange.send() }
    }
    
    // 开机启动开关
    var launchAtLogin: Bool {
        get { return userDefaults?.bool(forKey: "launchAtLogin") ?? false }
        set { userDefaults?.set(newValue, forKey: "launchAtLogin"); objectWillChange.send() }
    }
    
    // 启用 Extension 开关
    var extensionEnabled: Bool {
        get { return userDefaults?.bool(forKey: "extensionEnabled") ?? true }
        set { userDefaults?.set(newValue, forKey: "extensionEnabled"); objectWillChange.send() }
    }
}
