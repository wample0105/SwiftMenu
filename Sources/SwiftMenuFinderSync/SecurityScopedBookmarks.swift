import Foundation

/// 菜单热路径只检查类型标识，不提前解析剪贴板对象。
enum FilePasteboardContents {
    static let fileURLTypeIdentifier = "public.file-url"
    static let securityScopedBookmarksTypeIdentifier =
        "com.aporightmenu.SwiftMenu.security-scoped-bookmarks"

    static func containsPasteableFiles(typeIdentifiers: [String]) -> Bool {
        typeIdentifiers.contains(fileURLTypeIdentifier)
            || typeIdentifiers.contains(securityScopedBookmarksTypeIdentifier)
    }
}

/// 将 Finder 菜单动作中的临时文件权限转换为可在后续粘贴动作中恢复的安全书签。
enum SecurityScopedBookmarks {
    private static let payloadVersion = 1

    private struct Payload: Codable {
        let version: Int
        let bookmarks: [Data]
    }

    enum PayloadError: LocalizedError {
        case unsupportedVersion
        case emptyPayload

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion:
                return "剪贴板中的 SwiftMenu 文件权限数据版本不受支持。"
            case .emptyPayload:
                return "剪贴板中没有可粘贴的 SwiftMenu 文件权限数据。"
            }
        }
    }

    static func makePayload(for urls: [URL]) throws -> Data {
        let bookmarks = try urls.map(makeBookmark(for:))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(Payload(version: payloadVersion, bookmarks: bookmarks))
    }

    static func resolvePayload(_ data: Data) throws -> [URL] {
        let payload = try PropertyListDecoder().decode(Payload.self, from: data)
        guard payload.version == payloadVersion else {
            throw PayloadError.unsupportedVersion
        }
        guard !payload.bookmarks.isEmpty else {
            throw PayloadError.emptyPayload
        }
        return try payload.bookmarks.map(resolveBookmark(_:))
    }

    /// 立即把当前动作中的 URL 转换为自带 security scope 的 URL，供后台队列稍后使用。
    static func scopedURL(for url: URL) throws -> URL {
        try resolveBookmark(makeBookmark(for: url))
    }

    static func scopedURLs(for urls: [URL]) throws -> [URL] {
        try urls.map(scopedURL(for:))
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private static func resolveBookmark(_ data: Data) throws -> URL {
        var isStale = false
        return try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
