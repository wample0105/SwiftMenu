import Foundation

enum OfficeDocumentType {
    case word
    case spreadsheet
    case presentation
}

/// 生成最小、未压缩的 OOXML ZIP 容器。只在用户点击“新建”时执行，不影响菜单热路径。
enum OfficeDocumentFactory {
    static func documentData(for type: OfficeDocumentType) -> Data {
        switch type {
        case .word:
            return ZipArchive.make(entries: wordEntries)
        case .spreadsheet:
            return ZipArchive.make(entries: spreadsheetEntries)
        case .presentation:
            return ZipArchive.make(entries: presentationEntries)
        }
    }

    private static let wordEntries: [(String, Data)] = [
        ("[Content_Types].xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """)),
        ("_rels/.rels", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """)),
        ("word/document.xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p/><w:sectPr/></w:body>
        </w:document>
        """))
    ]

    private static let spreadsheetEntries: [(String, Data)] = [
        ("[Content_Types].xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """)),
        ("_rels/.rels", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """)),
        ("xl/workbook.xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """)),
        ("xl/_rels/workbook.xml.rels", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """)),
        ("xl/worksheets/sheet1.xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>
        """))
    ]

    private static let presentationEntries: [(String, Data)] = [
        ("[Content_Types].xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        </Types>
        """)),
        ("_rels/.rels", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """)),
        ("ppt/presentation.xml", xmlData("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldMasterIdLst/><p:sldIdLst/><p:sldSz cx="12192000" cy="6858000" type="screen16x9"/><p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle/>
        </p:presentation>
        """))
    ]

    private static func xmlData(_ value: String) -> Data {
        Data(value.utf8)
    }
}

private enum ZipArchive {
    private struct CentralEntry {
        let name: Data
        let contents: Data
        let checksum: UInt32
        let localHeaderOffset: UInt32
    }

    static func make(entries: [(String, Data)]) -> Data {
        var archive = Data()
        var centralEntries: [CentralEntry] = []

        for (name, contents) in entries {
            let nameData = Data(name.utf8)
            let checksum = crc32(contents)
            let localHeaderOffset = UInt32(archive.count)

            archive.appendLittleEndian(UInt32(0x04034b50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(checksum)
            archive.appendLittleEndian(UInt32(contents.count))
            archive.appendLittleEndian(UInt32(contents.count))
            archive.appendLittleEndian(UInt16(nameData.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(nameData)
            archive.append(contents)

            centralEntries.append(
                CentralEntry(
                    name: nameData,
                    contents: contents,
                    checksum: checksum,
                    localHeaderOffset: localHeaderOffset
                )
            )
        }

        let centralDirectoryOffset = UInt32(archive.count)
        for entry in centralEntries {
            archive.appendLittleEndian(UInt32(0x02014b50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(entry.checksum)
            archive.appendLittleEndian(UInt32(entry.contents.count))
            archive.appendLittleEndian(UInt32(entry.contents.count))
            archive.appendLittleEndian(UInt16(entry.name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt32(0))
            archive.appendLittleEndian(entry.localHeaderOffset)
            archive.append(entry.name)
        }

        let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset
        archive.appendLittleEndian(UInt32(0x06054b50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(centralEntries.count))
        archive.appendLittleEndian(UInt16(centralEntries.count))
        archive.appendLittleEndian(centralDirectorySize)
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var checksum: UInt32 = 0xffff_ffff
        for byte in data {
            checksum ^= UInt32(byte)
            for _ in 0..<8 {
                checksum = (checksum >> 1) ^ (0xedb8_8320 & (0 &- (checksum & 1)))
            }
        }
        return checksum ^ 0xffff_ffff
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
