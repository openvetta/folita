import Foundation
import SwiftData
import Testing
@testable import Folita

@MainActor
struct HistoryStorageTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func clip(_ text: String) -> CapturedClip {
        CapturedClip(contents: [ClipContent(type: .string, data: Data(text.utf8))], sourceBundleID: nil)
    }

    @Test func persistsAcrossReopen() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(path: "History")

        do {
            let opened = HistoryStorage.open(in: directory)
            #expect(opened.backupURL == nil)
            ClipboardHistoryStore(container: opened.container, limit: { 500 }).record(clip("kept"))
        }

        let reopened = HistoryStorage.open(in: directory)
        let store = ClipboardHistoryStore(container: reopened.container, limit: { 500 })
        #expect(store.items.map(\.title) == ["kept"])
    }

    @Test func corruptedStoreIsBackedUpAndRecreated() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(path: "History")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not a database".utf8).write(to: directory.appending(path: "History.store"))

        let opened = HistoryStorage.open(in: directory)

        let backup = try #require(opened.backupURL)
        #expect(FileManager.default.fileExists(atPath: backup.appending(path: "History.store").path))
        let store = ClipboardHistoryStore(container: opened.container, limit: { 500 })
        store.record(clip("fresh"))
        #expect(store.items.map(\.title) == ["fresh"])
    }
}
