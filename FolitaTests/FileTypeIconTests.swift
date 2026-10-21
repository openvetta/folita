import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Folita

@MainActor
struct FileTypeIconTests {
    @Test(arguments: [("pdf", UTType.pdf), ("docx", UTType("org.openxmlformats.wordprocessingml.document")!), ("zip", UTType.zip)])
    func singleFileUsesItsExtensionType(ext: String, expected: UTType) {
        #expect(FileTypeIcon.contentType(for: [URL(filePath: "/tmp/report.\(ext)")]) == expected)
    }

    @Test func foldersUseFolderType() {
        #expect(FileTypeIcon.contentType(for: [URL(filePath: "/tmp/dir", directoryHint: .isDirectory)]) == .folder)
    }

    @Test func unknownMultipleOrEmptyFallBackToGenericType() {
        #expect(FileTypeIcon.contentType(for: [URL(filePath: "/tmp/noext")]) == .data)
        #expect(FileTypeIcon.contentType(for: [URL(filePath: "/tmp/a.pdf"), URL(filePath: "/tmp/b.pdf")]) == .data)
        #expect(FileTypeIcon.contentType(for: []) == .data)
    }

    @Test func distinctTypesGetDistinctIcons() {
        let pdf = FileTypeIcon.image(for: [URL(filePath: "/tmp/a.pdf")])
        let generic = FileTypeIcon.image(for: [URL(filePath: "/tmp/a.unknownext123")])
        #expect(pdf.size.width > 0 && generic.size.width > 0)
        #expect(pdf.tiffRepresentation != generic.tiffRepresentation)
    }
}
