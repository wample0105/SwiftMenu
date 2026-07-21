import SwiftUI

@main
struct SettingsVisualHarness: App {
    private let initialTab: SettingsTab = {
        if CommandLine.arguments.contains("--general") {
            return .general
        }
        if CommandLine.arguments.contains("--menu-order") {
            return .menuOrder
        }
        return .about
    }()

    var body: some Scene {
        WindowGroup("SwiftMenu 设置预览") {
            SettingsView(initialTab: initialTab)
        }
    }
}
