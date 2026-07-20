import Foundation
import Darwin

enum FileTransferMode: Sendable, Equatable {
    case copy
    case move
}

enum FileConflictPolicy: Sendable {
    case replace
    case skip
    case keepBoth
}

struct FileTransferRequest: Sendable {
    let sources: [URL]
    let destinationFolder: URL
    let mode: FileTransferMode
    let conflictPolicy: FileConflictPolicy
}

struct FileTransferFailure: Sendable {
    let source: URL
    let message: String
}

struct FileTransferResult: Sendable {
    let completedCount: Int
    let skippedCount: Int
    let failures: [FileTransferFailure]

    var succeeded: Bool { failures.isEmpty }
}

/// Foundation-only file operation engine. It never touches AppKit and is safe to run off the main thread.
final class FileTransferEngine: @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func perform(_ request: FileTransferRequest) -> FileTransferResult {
        var completedCount = 0
        var skippedCount = 0
        var failures: [FileTransferFailure] = []

        let didAccessDestination = request.destinationFolder.startAccessingSecurityScopedResource()
        defer {
            if didAccessDestination {
                request.destinationFolder.stopAccessingSecurityScopedResource()
            }
        }

        for source in request.sources {
            autoreleasepool {
                let didAccessSecurityScope = source.startAccessingSecurityScopedResource()
                defer {
                    if didAccessSecurityScope {
                        source.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let outcome = try transfer(source, request: request)
                    switch outcome {
                    case .completed:
                        completedCount += 1
                    case .skipped:
                        skippedCount += 1
                    }
                } catch {
                    failures.append(
                        FileTransferFailure(
                            source: source,
                            message: error.localizedDescription
                        )
                    )
                }
            }
        }

        return FileTransferResult(
            completedCount: completedCount,
            skippedCount: skippedCount,
            failures: failures
        )
    }

    func hasConflict(sources: [URL], destinationFolder: URL) -> Bool {
        let didAccessDestination = destinationFolder.startAccessingSecurityScopedResource()
        defer {
            if didAccessDestination {
                destinationFolder.stopAccessingSecurityScopedResource()
            }
        }

        return sources.contains { source in
            let destination = destinationFolder.appendingPathComponent(source.lastPathComponent)
            return source.standardizedFileURL != destination.standardizedFileURL
                && fileManager.fileExists(atPath: destination.path)
        }
    }

    static func uniqueDestination(for url: URL, fileManager: FileManager = .default) -> URL {
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension

        var counter = 1
        var candidate = url
        while fileManager.fileExists(atPath: candidate.path) {
            let candidateName = pathExtension.isEmpty
                ? "\(filename) \(counter)"
                : "\(filename) \(counter).\(pathExtension)"
            candidate = directory.appendingPathComponent(candidateName)
            counter += 1
        }
        return candidate
    }

    private enum TransferOutcome {
        case completed
        case skipped
    }

    private func transfer(_ source: URL, request: FileTransferRequest) throws -> TransferOutcome {
        guard fileManager.fileExists(atPath: source.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try validateDestination(request.destinationFolder, for: source)

        var destination = request.destinationFolder.appendingPathComponent(source.lastPathComponent)
        let isSameLocation = source.standardizedFileURL == destination.standardizedFileURL

        if isSameLocation {
            if request.mode == .move {
                return .skipped
            }
            destination = Self.uniqueDestination(for: destination, fileManager: fileManager)
        } else if fileManager.fileExists(atPath: destination.path) {
            switch request.conflictPolicy {
            case .skip:
                return .skipped
            case .keepBoth:
                destination = Self.uniqueDestination(for: destination, fileManager: fileManager)
            case .replace:
                try safelyReplace(source: source, destination: destination, mode: request.mode)
                return .completed
            }
        }

        switch request.mode {
        case .copy:
            try copyAtomically(source: source, destination: destination)
        case .move:
            try moveReliably(source: source, destination: destination)
        }
        return .completed
    }

    private func safelyReplace(source: URL, destination: URL, mode: FileTransferMode) throws {
        let stagingURL = makeStagingURL(beside: destination)

        do {
            try fileManager.copyItem(at: source, to: stagingURL)
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: []
            )

            if mode == .move {
                try fileManager.removeItem(at: source)
            }
        } catch {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
            throw error
        }
    }

    /// 所有复制先写入目标目录中的隐藏暂存项，再通过同卷 rename 原子落位。
    private func copyAtomically(source: URL, destination: URL) throws {
        let stagingURL = makeStagingURL(beside: destination)
        do {
            try fileManager.copyItem(at: source, to: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: destination)
        } catch {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
            throw error
        }
    }

    /// 同卷移动使用文件系统 rename；跨卷移动先安全复制，完成后再删除源文件。
    private func moveReliably(source: URL, destination: URL) throws {
        if isOnSameVolume(source, destination.deletingLastPathComponent()) {
            try fileManager.moveItem(at: source, to: destination)
        } else {
            try copyAtomically(source: source, destination: destination)
            try fileManager.removeItem(at: source)
        }
    }

    private func makeStagingURL(beside destination: URL) -> URL {
        destination
            .deletingLastPathComponent()
            .appendingPathComponent(".swiftmenu-staging-\(UUID().uuidString)")
    }

    private func isOnSameVolume(_ source: URL, _ destinationFolder: URL) -> Bool {
        var sourceInfo = stat()
        var destinationInfo = stat()
        guard lstat(source.path, &sourceInfo) == 0,
              stat(destinationFolder.path, &destinationInfo) == 0 else {
            return false
        }
        return sourceInfo.st_dev == destinationInfo.st_dev
    }

    private func validateDestination(_ destinationFolder: URL, for source: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationFolder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }

        var sourceIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory),
              sourceIsDirectory.boolValue else {
            return
        }

        let sourceComponents = source.standardizedFileURL.pathComponents
        let destinationComponents = destinationFolder.standardizedFileURL.pathComponents
        if destinationComponents.starts(with: sourceComponents), destinationComponents.count > sourceComponents.count {
            throw CocoaError(.fileWriteInvalidFileName)
        }
    }
}
