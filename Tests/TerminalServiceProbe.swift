import Foundation

/// 手工集成测试：在真实 App Sandbox 中调用系统 Terminal 服务。
/// 构建脚本不会默认执行，避免日常测试时反复弹出终端窗口。
@main
struct TerminalServiceProbe {
    @MainActor
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("用法：TerminalServiceProbe <目录>\n".utf8))
            exit(2)
        }

        let target = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let succeeded = TerminalLauncher.open(target: target)
        print(succeeded ? "terminal_service=success" : "terminal_service=failure")
        exit(succeeded ? 0 : 1)
    }
}
