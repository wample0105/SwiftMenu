import AppKit

/// 仅用于本地估算扩展框架常驻基线；不替代 Finder 宿主中的 Instruments 测量。
@main
@MainActor
struct FinderSyncIdleHarness {
    private static var finderSync: FinderSync?

    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        finderSync = FinderSync()

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            application.terminate(nil)
        }
        application.run()
    }
}
