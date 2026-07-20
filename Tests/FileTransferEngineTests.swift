import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message): return message
        }
    }
}

@main
struct FileTransferEngineTests {
    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("复制到空目录", testCopy),
            ("原地复制自动重命名", testCopyInPlace),
            ("保留两者", testKeepBoth),
            ("跳过冲突", testSkip),
            ("安全替换", testReplace),
            ("安全替换目录", testReplaceDirectory),
            ("移动文件", testMove),
            ("移动并替换", testMoveAndReplace),
            ("原地移动不改名", testMoveInPlace),
            ("防止复制目录到自身子目录", testRejectDescendantDestination),
            ("首次启动默认菜单全部启用", testDefaultSettings),
            ("无效菜单顺序自动修复", testMenuOrderValidation),
            ("终端打开目录保持原路径", testTerminalFolderTarget),
            ("终端打开文件时使用父目录", testTerminalFileTarget),
            ("安全书签单文件往返", testSecurityScopedBookmarkRoundTrip),
            ("安全书签多文件载荷往返", testSecurityScopedBookmarkPayload),
            ("拒绝损坏的安全书签载荷", testInvalidSecurityScopedBookmarkPayload),
            ("系统文件 URL 类型显示粘贴", testSystemFileURLShowsPaste),
            ("SwiftMenu 安全书签类型显示粘贴", testSwiftMenuBookmarksShowPaste),
            ("剪切标记不能单独显示粘贴", testCutMarkerDoesNotShowPaste),
            ("空剪贴板不显示粘贴", testEmptyPasteboardDoesNotShowPaste),
            ("Word 模板是合法 OOXML", testWordTemplate),
            ("Excel 模板是合法 OOXML", testSpreadsheetTemplate),
            ("PowerPoint 模板是合法 OOXML", testPresentationTemplate)
        ]

        var failed = 0
        for (name, test) in tests {
            do {
                try test()
                print("✅ \(name)")
            } catch {
                failed += 1
                print("❌ \(name)：\(error)")
            }
        }

        guard failed == 0 else {
            throw TestFailure.assertion("\(failed) 项测试失败")
        }
        print("\n全部 \(tests.count) 项核心逻辑测试通过。")
    }

    private static func testCopy() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "source", in: sourceFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .copy, policy: .keepBoth)
            )

            try expect(result.succeeded && result.completedCount == 1, "复制应成功")
            try expect(try contents(of: destinationFolder.appendingPathComponent("demo.txt")) == "source", "目标内容不正确")
            try expect(FileManager.default.fileExists(atPath: source.path), "复制后源文件应保留")
        }
    }

    private static func testCopyInPlace() throws {
        try withTemporaryDirectory { root in
            let source = try makeFile("demo.txt", contents: "source", in: root)
            let result = FileTransferEngine().perform(
                request(sources: [source], destination: root, mode: .copy, policy: .replace)
            )

            try expect(result.succeeded, "原地复制应成功")
            try expect(try contents(of: root.appendingPathComponent("demo 1.txt")) == "source", "应生成带序号的副本")
            try expect(try contents(of: source) == "source", "原文件不应被覆盖")
        }
    }

    private static func testKeepBoth() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "new", in: sourceFolder)
            _ = try makeFile("demo.txt", contents: "old", in: destinationFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .copy, policy: .keepBoth)
            )

            try expect(result.succeeded, "保留两者应成功")
            try expect(try contents(of: destinationFolder.appendingPathComponent("demo.txt")) == "old", "原目标不应变化")
            try expect(try contents(of: destinationFolder.appendingPathComponent("demo 1.txt")) == "new", "副本内容不正确")
        }
    }

    private static func testSkip() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "new", in: sourceFolder)
            let destination = try makeFile("demo.txt", contents: "old", in: destinationFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .copy, policy: .skip)
            )

            try expect(result.succeeded && result.skippedCount == 1, "冲突项应跳过")
            try expect(try contents(of: destination) == "old", "跳过不应改变目标")
        }
    }

    private static func testReplace() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "new", in: sourceFolder)
            let destination = try makeFile("demo.txt", contents: "old", in: destinationFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .copy, policy: .replace)
            )

            try expect(result.succeeded, "替换应成功")
            try expect(try contents(of: destination) == "new", "替换后的内容不正确")
            try expect(try contents(of: source) == "new", "复制替换不应删除源文件")
            let stagingFiles = try FileManager.default.contentsOfDirectory(atPath: destinationFolder.path)
                .filter { $0.hasPrefix(".swiftmenu-staging-") }
            try expect(stagingFiles.isEmpty, "替换完成后不应残留暂存文件")
        }
    }

    private static func testMove() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "source", in: sourceFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .move, policy: .keepBoth)
            )

            try expect(result.succeeded, "移动应成功")
            try expect(!FileManager.default.fileExists(atPath: source.path), "移动后源文件应不存在")
            try expect(try contents(of: destinationFolder.appendingPathComponent("demo.txt")) == "source", "移动后的内容不正确")
        }
    }

    private static func testReplaceDirectory() throws {
        try withTemporaryDirectory { root in
            let sourceParent = try makeDirectory("source-parent", in: root)
            let destinationParent = try makeDirectory("destination-parent", in: root)
            let sourceFolder = try makeDirectory("documents", in: sourceParent)
            let destinationFolder = try makeDirectory("documents", in: destinationParent)
            _ = try makeFile("new.txt", contents: "new", in: sourceFolder)
            _ = try makeFile("old.txt", contents: "old", in: destinationFolder)

            let result = FileTransferEngine().perform(
                request(sources: [sourceFolder], destination: destinationParent, mode: .copy, policy: .replace)
            )

            try expect(result.succeeded, "目录替换应成功")
            try expect(
                try contents(of: destinationFolder.appendingPathComponent("new.txt")) == "new",
                "替换后的目录内容不正确"
            )
            try expect(
                !FileManager.default.fileExists(atPath: destinationFolder.appendingPathComponent("old.txt").path),
                "替换后不应保留旧目录内容"
            )
        }
    }

    private static func testMoveAndReplace() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let destinationFolder = try makeDirectory("destination", in: root)
            let source = try makeFile("demo.txt", contents: "new", in: sourceFolder)
            let destination = try makeFile("demo.txt", contents: "old", in: destinationFolder)

            let result = FileTransferEngine().perform(
                request(sources: [source], destination: destinationFolder, mode: .move, policy: .replace)
            )

            try expect(result.succeeded, "移动替换应成功")
            try expect(!FileManager.default.fileExists(atPath: source.path), "移动替换后源文件应删除")
            try expect(try contents(of: destination) == "new", "移动替换后的内容不正确")
        }
    }

    private static func testMoveInPlace() throws {
        try withTemporaryDirectory { root in
            let source = try makeFile("demo.txt", contents: "source", in: root)
            let result = FileTransferEngine().perform(
                request(sources: [source], destination: root, mode: .move, policy: .replace)
            )

            try expect(result.succeeded && result.skippedCount == 1, "原地移动应跳过")
            try expect(try contents(of: source) == "source", "原地移动不应重命名或删除源文件")
            try expect(
                !FileManager.default.fileExists(atPath: root.appendingPathComponent("demo 1.txt").path),
                "原地移动不应创建副本"
            )
        }
    }

    private static func testRejectDescendantDestination() throws {
        try withTemporaryDirectory { root in
            let sourceFolder = try makeDirectory("source", in: root)
            let childFolder = try makeDirectory("child", in: sourceFolder)
            _ = try makeFile("demo.txt", contents: "source", in: sourceFolder)

            let result = FileTransferEngine().perform(
                request(sources: [sourceFolder], destination: childFolder, mode: .copy, policy: .keepBoth)
            )

            try expect(!result.succeeded && result.failures.count == 1, "复制目录到自身子目录必须失败")
        }
    }

    private static func testDefaultSettings() throws {
        try withTemporaryDefaults { defaults in
            let snapshot = AppSettings(userDefaults: defaults).snapshot()
            try expect(snapshot.enableNewTXT, "TXT 默认应启用")
            try expect(snapshot.enableNewWord, "Word 默认应启用")
            try expect(snapshot.enableNewExcel, "Excel 默认应启用")
            try expect(snapshot.enableNewPPT, "PPT 默认应启用")
            try expect(snapshot.enableNewMarkdown, "Markdown 默认应启用")
            try expect(snapshot.enableCopyPath, "复制路径默认应启用")
            try expect(snapshot.enableOpenInTerminal, "终端默认应启用")
            try expect(snapshot.enableCut && snapshot.enableCopy && snapshot.enablePaste, "剪切复制粘贴默认应启用")
            try expect(snapshot.menuOrder == ["newFile", "copy", "cut", "paste", "copyPath", "openInTerminal"], "默认顺序不正确")
        }
    }

    private static func testMenuOrderValidation() throws {
        try withTemporaryDefaults { defaults in
            defaults.set(["paste", "paste", "invalid", "copy"], forKey: "menuOrder")
            let snapshot = AppSettings(userDefaults: defaults).snapshot()
            try expect(
                snapshot.menuOrder == ["paste", "copy", "newFile", "cut", "copyPath", "openInTerminal"],
                "菜单顺序应去重、移除未知项并补齐缺失项"
            )
        }
    }

    private static func testTerminalFolderTarget() throws {
        try withTemporaryDirectory { root in
            try expect(TerminalLauncher.folderURL(for: root) == root, "目录目标不应被改写")
        }
    }

    private static func testTerminalFileTarget() throws {
        try withTemporaryDirectory { root in
            let file = try makeFile("demo.txt", contents: "source", in: root)
            try expect(TerminalLauncher.folderURL(for: file) == root, "文件目标应转换为父目录")
        }
    }

    private static func testSecurityScopedBookmarkRoundTrip() throws {
        try withTemporaryDirectory { root in
            let file = try makeFile("demo.txt", contents: "source", in: root)
            let scopedURL = try SecurityScopedBookmarks.scopedURL(for: file)
            try expect(scopedURL.standardizedFileURL == file.standardizedFileURL, "安全书签解析路径不一致")
            try expect(try contents(of: scopedURL) == "source", "安全书签解析后应能读取文件")
        }
    }

    private static func testSecurityScopedBookmarkPayload() throws {
        try withTemporaryDirectory { root in
            let first = try makeFile("first.txt", contents: "first", in: root)
            let second = try makeFile("second.txt", contents: "second", in: root)
            let payload = try SecurityScopedBookmarks.makePayload(for: [first, second])
            let resolved = try SecurityScopedBookmarks.resolvePayload(payload)
            try expect(
                resolved.map(\.standardizedFileURL) == [first.standardizedFileURL, second.standardizedFileURL],
                "多文件安全书签载荷顺序或路径不一致"
            )
        }
    }

    private static func testInvalidSecurityScopedBookmarkPayload() throws {
        do {
            _ = try SecurityScopedBookmarks.resolvePayload(Data("invalid".utf8))
            throw TestFailure.assertion("损坏的安全书签载荷必须被拒绝")
        } catch is TestFailure {
            throw TestFailure.assertion("损坏的安全书签载荷必须被拒绝")
        } catch {
            return
        }
    }

    private static func testSystemFileURLShowsPaste() throws {
        try expect(
            FilePasteboardContents.containsPasteableFiles(
                typeIdentifiers: [FilePasteboardContents.fileURLTypeIdentifier]
            ),
            "系统文件 URL 类型应显示粘贴"
        )
    }

    private static func testSwiftMenuBookmarksShowPaste() throws {
        try expect(
            FilePasteboardContents.containsPasteableFiles(
                typeIdentifiers: [FilePasteboardContents.securityScopedBookmarksTypeIdentifier]
            ),
            "SwiftMenu 安全书签载荷应独立显示粘贴"
        )
    }

    private static func testCutMarkerDoesNotShowPaste() throws {
        try expect(
            !FilePasteboardContents.containsPasteableFiles(
                typeIdentifiers: ["com.apple.finder.node.cut"]
            ),
            "只有剪切标记时不应显示粘贴"
        )
    }

    private static func testEmptyPasteboardDoesNotShowPaste() throws {
        try expect(
            !FilePasteboardContents.containsPasteableFiles(typeIdentifiers: []),
            "空剪贴板不应显示粘贴"
        )
    }

    private static func testWordTemplate() throws {
        try validateOfficeArchive(
            data: OfficeDocumentFactory.documentData(for: .word),
            extension: "docx",
            requiredEntries: ["[Content_Types].xml", "_rels/.rels", "word/document.xml"]
        )
    }

    private static func testSpreadsheetTemplate() throws {
        try validateOfficeArchive(
            data: OfficeDocumentFactory.documentData(for: .spreadsheet),
            extension: "xlsx",
            requiredEntries: [
                "[Content_Types].xml",
                "_rels/.rels",
                "xl/workbook.xml",
                "xl/_rels/workbook.xml.rels",
                "xl/worksheets/sheet1.xml"
            ]
        )
    }

    private static func testPresentationTemplate() throws {
        try validateOfficeArchive(
            data: OfficeDocumentFactory.documentData(for: .presentation),
            extension: "pptx",
            requiredEntries: ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml"]
        )
    }

    private static func request(
        sources: [URL],
        destination: URL,
        mode: FileTransferMode,
        policy: FileConflictPolicy
    ) -> FileTransferRequest {
        FileTransferRequest(
            sources: sources,
            destinationFolder: destination,
            mode: mode,
            conflictPolicy: policy
        )
    }

    private static func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftMenuTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private static func withTemporaryDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "com.aporightmenu.SwiftMenu.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure.assertion("无法创建临时 UserDefaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    private static func validateOfficeArchive(
        data: Data,
        extension pathExtension: String,
        requiredEntries: [String]
    ) throws {
        try withTemporaryDirectory { root in
            let archiveURL = root.appendingPathComponent("document.\(pathExtension)")
            try data.write(to: archiveURL)

            let testProcess = Process()
            testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            testProcess.arguments = ["-t", archiveURL.path]
            testProcess.standardOutput = FileHandle.nullDevice
            testProcess.standardError = FileHandle.nullDevice
            try testProcess.run()
            testProcess.waitUntilExit()
            try expect(testProcess.terminationStatus == 0, "OOXML ZIP 完整性检查失败")

            let listProcess = Process()
            let output = Pipe()
            listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            listProcess.arguments = ["-Z1", archiveURL.path]
            listProcess.standardOutput = output
            listProcess.standardError = FileHandle.nullDevice
            try listProcess.run()
            let entryData = output.fileHandleForReading.readDataToEndOfFile()
            listProcess.waitUntilExit()
            try expect(listProcess.terminationStatus == 0, "无法读取 OOXML 目录")

            let entries = Set(String(decoding: entryData, as: UTF8.self).split(separator: "\n").map(String.init))
            for requiredEntry in requiredEntries {
                try expect(entries.contains(requiredEntry), "OOXML 缺少 \(requiredEntry)")
            }
        }
    }

    private static func makeDirectory(_ name: String, in parent: URL) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func makeFile(_ name: String, contents: String, in parent: URL) throws -> URL {
        let url = parent.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure.assertion(message) }
    }
}
