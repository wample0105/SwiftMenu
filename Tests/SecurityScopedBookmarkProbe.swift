import Foundation

/// 手工集成测试：验证安全书签在 App 重新签名并失去原始静态目录权限后仍可恢复访问。
@main
struct SecurityScopedBookmarkProbe {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            throw ProbeError.invalidArguments
        }

        let payloadURL = try payloadFileURL()
        switch CommandLine.arguments[1] {
        case "create":
            guard CommandLine.arguments.count == 3 else { throw ProbeError.invalidArguments }
            let source = URL(fileURLWithPath: CommandLine.arguments[2])
            let payload = try SecurityScopedBookmarks.makePayload(for: [source])
            try payload.write(to: payloadURL, options: .atomic)
            print("bookmark_created=\(source.path)")

        case "create-move":
            guard CommandLine.arguments.count == 3 else { throw ProbeError.invalidArguments }
            let source = URL(fileURLWithPath: CommandLine.arguments[2])
            try Data("SwiftMenu sandbox bookmark move probe".utf8).write(to: source, options: .atomic)
            let payload = try SecurityScopedBookmarks.makePayload(for: [source])
            try payload.write(to: payloadURL, options: .atomic)
            print("move_bookmark_created=\(source.path)")

        case "resolve":
            let payload = try Data(contentsOf: payloadURL)
            guard let source = try SecurityScopedBookmarks.resolvePayload(payload).first else {
                throw ProbeError.missingSource
            }
            let didAccess = source.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    source.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: source)
            print("bookmark_resolved_bytes=\(data.count)")

        case "resolve-move":
            let payload = try Data(contentsOf: payloadURL)
            guard let source = try SecurityScopedBookmarks.resolvePayload(payload).first else {
                throw ProbeError.missingSource
            }
            let destinationFolder = try transferDestinationFolder()
            let result = FileTransferEngine().perform(
                FileTransferRequest(
                    sources: [source],
                    destinationFolder: destinationFolder,
                    mode: .move,
                    conflictPolicy: .keepBoth
                )
            )
            guard result.succeeded, result.completedCount == 1 else {
                throw ProbeError.transferFailed(result.failures.first?.message ?? "未知错误")
            }
            print("bookmark_move=success")

        default:
            throw ProbeError.invalidArguments
        }
    }

    private static func payloadFileURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ProbeError.missingApplicationSupport
        }
        try FileManager.default.createDirectory(
            at: applicationSupport,
            withIntermediateDirectories: true
        )
        return applicationSupport.appendingPathComponent("security-scoped-bookmark-payload.plist")
    }

    private static func transferDestinationFolder() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ProbeError.missingApplicationSupport
        }
        let destination = applicationSupport.appendingPathComponent("move-result", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }

    private enum ProbeError: LocalizedError {
        case invalidArguments
        case missingApplicationSupport
        case missingSource
        case transferFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidArguments:
                return "用法：SecurityScopedBookmarkProbe create <源文件> | resolve | create-move <临时源文件> | resolve-move"
            case .missingApplicationSupport:
                return "无法定位 App Sandbox 的 Application Support 目录。"
            case .missingSource:
                return "安全书签载荷中没有源文件。"
            case .transferFailed(let message):
                return "安全书签移动失败：\(message)"
            }
        }
    }
}
