import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultMenuOrder = ["newFile", "copy", "cut", "paste", "copyPath", "openInTerminal"]

    private static let defaultValues: [String: Any] = [
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

    private let userDefaults: UserDefaults

    var enableNewTXT: Bool {
        get { userDefaults.bool(forKey: "enableNewTXT") }
        set { set(newValue, forKey: "enableNewTXT") }
    }

    var enableNewWord: Bool {
        get { userDefaults.bool(forKey: "enableNewWord") }
        set { set(newValue, forKey: "enableNewWord") }
    }

    var enableNewExcel: Bool {
        get { userDefaults.bool(forKey: "enableNewExcel") }
        set { set(newValue, forKey: "enableNewExcel") }
    }

    var enableNewPPT: Bool {
        get { userDefaults.bool(forKey: "enableNewPPT") }
        set { set(newValue, forKey: "enableNewPPT") }
    }

    var enableNewMarkdown: Bool {
        get { userDefaults.bool(forKey: "enableNewMarkdown") }
        set { set(newValue, forKey: "enableNewMarkdown") }
    }

    var enableCopyPath: Bool {
        get { userDefaults.bool(forKey: "enableCopyPath") }
        set { set(newValue, forKey: "enableCopyPath") }
    }

    var enableOpenInTerminal: Bool {
        get { userDefaults.bool(forKey: "enableOpenInTerminal") }
        set { set(newValue, forKey: "enableOpenInTerminal") }
    }

    var enableCut: Bool {
        get { userDefaults.bool(forKey: "enableCut") }
        set { set(newValue, forKey: "enableCut") }
    }

    var enableCopy: Bool {
        get { userDefaults.bool(forKey: "enableCopy") }
        set { set(newValue, forKey: "enableCopy") }
    }

    var enablePaste: Bool {
        get { userDefaults.bool(forKey: "enablePaste") }
        set { set(newValue, forKey: "enablePaste") }
    }

    @Published var menuOrder: [String] {
        didSet {
            userDefaults.set(menuOrder, forKey: "menuOrder")
        }
    }

    private init() {
        let defaults = UserDefaults(suiteName: "group.com.aporightmenu") ?? .standard
        userDefaults = defaults
        defaults.register(defaults: Self.defaultValues)
        menuOrder = Self.validatedMenuOrder(defaults.stringArray(forKey: "menuOrder"))
    }

    func registerDefaultsIfNeeded() {
        userDefaults.register(defaults: Self.defaultValues)
    }

    private func set(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
        objectWillChange.send()
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
