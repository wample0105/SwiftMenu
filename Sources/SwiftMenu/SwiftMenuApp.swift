import SwiftUI

@main
struct SwiftMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup("SwiftMenu") {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
