import Foundation

@main
struct GenerateOfficeTemplates {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        try OfficeDocumentFactory.documentData(for: .word)
            .write(to: outputDirectory.appendingPathComponent("空白文档.docx"))
        try OfficeDocumentFactory.documentData(for: .spreadsheet)
            .write(to: outputDirectory.appendingPathComponent("空白表格.xlsx"))
        try OfficeDocumentFactory.documentData(for: .presentation)
            .write(to: outputDirectory.appendingPathComponent("空白演示.pptx"))
    }
}
