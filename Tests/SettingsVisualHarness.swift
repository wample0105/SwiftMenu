import SwiftUI

@main
struct SettingsVisualHarness: App {
    private let initialTab: SettingsTab = CommandLine.arguments.contains("--general")
        ? .general
        : .about

    var body: some Scene {
        WindowGroup("SwiftMenu 设置预览") {
            SettingsView(initialTab: initialTab)
        }
    }
}
