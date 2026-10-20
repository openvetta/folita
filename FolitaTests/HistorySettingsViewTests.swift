import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct HistorySettingsViewTests {
    @Test func loweringLimitTrimsOldestImmediately() {
        let services = TestServices(copying: ["1", "2", "3", "4", "5"])
        // 与 AppDelegate 的装配一致。
        let store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { services.history.limit })
        services.history.onLimitChange = { store.enforceLimit() }
        for index in 1...150 {
            store.record(CapturedClip(contents: [ClipContent(type: .string, data: Data("\(index)".utf8))], sourceBundleID: nil))
        }
        #expect(store.items.count == 150)

        services.history.limit = 100
        #expect(store.items.count == 100)
        #expect(store.items.first?.title == "150")
        #expect(store.items.last?.title == "51")
    }

    @Test func diskUsageSumsFilesRecursively() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(HistoryStorage.diskUsage(of: root) == 0)

        try FileManager.default.createDirectory(at: root.appending(path: "nested"), withIntermediateDirectories: true)
        try Data(count: 10_000).write(to: root.appending(path: "a.bin"))
        try Data(count: 20_000).write(to: root.appending(path: "nested/b.bin"))
        #expect(HistoryStorage.diskUsage(of: root) >= 30_000)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func laysOut(locale: String, scheme: ColorScheme) {
        let services = TestServices(copying: ["a", "b"])
        let view = HistorySettingsView(storageDirectory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
            .testServices(services, locale: locale, scheme: scheme)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 520)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)
    }
}
