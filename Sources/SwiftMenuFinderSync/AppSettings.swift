import Foundation

struct MenuSettingsSnapshot: Sendable {
    let enableNewTXT: Bool
    let enableNewWord: Bool
    let enableNewExcel: Bool
    let enableNewPPT: Bool
    let enableNewMarkdown: Bool
    let enableCopyPath: Bool
    let enableOpenInTerminal: Bool
    let enableCut: Bool
    let enableCopy: Bool
    let enablePaste: Bool
    let menuOrder: [String]
}

/// Finder 扩展使用 Foundation-only 设置读取器，避免加载 Combine/SwiftUI。
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()
    private static let defaultMenuOrder = ["newFile", "copy", "cut", "paste", "copyPath", "openInTerminal"]

    private static var defaultValues: [String: Any] {
        [
            "enableNewTXT": true,
            "enableNewWord": true,
            "enableNewExcel": true,
            "enableNewPPT": true,
            "enableNewMarkdown": true,
            "enableCopyPath": true,
            "enableOpenInTerminal": true,
            "enableCut": true,
            "enableCopy": true,
            "enablePaste": true,
            "menuOrder": defaultMenuOrder
        ]
    }

    private let userDefaults: UserDefaults

    private init() {
        let defaults = UserDefaults(suiteName: "group.com.aporightmenu") ?? .standard
        userDefaults = defaults
        defaults.register(defaults: Self.defaultValues)
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: Self.defaultValues)
    }

    /// 每次弹出菜单只读取一份完整快照，保证同一次构造中的配置一致。
    func snapshot() -> MenuSettingsSnapshot {
        MenuSettingsSnapshot(
            enableNewTXT: userDefaults.bool(forKey: "enableNewTXT"),
            enableNewWord: userDefaults.bool(forKey: "enableNewWord"),
            enableNewExcel: userDefaults.bool(forKey: "enableNewExcel"),
            enableNewPPT: userDefaults.bool(forKey: "enableNewPPT"),
            enableNewMarkdown: userDefaults.bool(forKey: "enableNewMarkdown"),
            enableCopyPath: userDefaults.bool(forKey: "enableCopyPath"),
            enableOpenInTerminal: userDefaults.bool(forKey: "enableOpenInTerminal"),
            enableCut: userDefaults.bool(forKey: "enableCut"),
            enableCopy: userDefaults.bool(forKey: "enableCopy"),
            enablePaste: userDefaults.bool(forKey: "enablePaste"),
            menuOrder: Self.validatedMenuOrder(userDefaults.stringArray(forKey: "menuOrder"))
        )
    }

    private static func validatedMenuOrder(_ value: [String]?) -> [String] {
        guard let value else { return defaultMenuOrder }
        let knownItems = Set(defaultMenuOrder)
        let uniqueKnownItems = value.reduce(into: [String]()) { result, item in
            if knownItems.contains(item), !result.contains(item) {
                result.append(item)
            }
        }
        return uniqueKnownItems + defaultMenuOrder.filter { !uniqueKnownItems.contains($0) }
    }
}
