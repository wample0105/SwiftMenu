import Foundation

/// 手工集成测试：用 Finder 扩展同等沙盒权限验证指定目录可真实创建和删除文件。
@main
struct SandboxFileAccessProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw ProbeError.invalidArguments
        }

        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let probe = directory.appendingPathComponent(".swiftmenu-write-probe-\(UUID().uuidString)")
        let expected = Data("SwiftMenu sandbox file access probe".utf8)

        try expected.write(to: probe, options: .atomic)
        defer { try? FileManager.default.removeItem(at: probe) }

        let actual = try Data(contentsOf: probe)
        guard actual == expected else {
            throw ProbeError.contentMismatch
        }

        print("sandbox_directory_write=success path=\(directory.path)")
    }

    private enum ProbeError: LocalizedError {
        case invalidArguments
        case contentMismatch

        var errorDescription: String? {
            switch self {
            case .invalidArguments:
                return "用法：SandboxFileAccessProbe <目标目录>"
            case .contentMismatch:
                return "沙盒写入后的文件内容不一致。"
            }
        }
    }
}
