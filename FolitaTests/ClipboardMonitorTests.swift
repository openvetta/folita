import AppKit
import SwiftData
import Testing
@testable import Folita

/// 从剪贴板变化到历史入库的完整采集流程。使用唯一命名的剪贴板，不触碰系统剪贴板。
@MainActor
final class ClipboardMonitorTests {
    private let pasteboard = NSPasteboard(name: .init("FolitaTests.\(UUID().uuidString)"))
    private let suiteName = "FolitaTests.Privacy.\(UUID().uuidString)"
    private let privacy: PrivacySettings
    private let store: ClipboardHistoryStore
    private var frontmost: String? = "com.apple.TextEdit"
    private lazy var monitor = ClipboardMonitor(
        pasteboard: pasteboard,
        privacy: privacy,
        frontmostBundleID: { [unowned self] in self.frontmost },
        onCapture: { [store] in store.record($0) }
    )

    init() throws {
        privacy = PrivacySettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        let container = try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ClipboardHistoryStore(container: container, limit: { 500 })
    }

    isolated deinit {
        pasteboard.releaseGlobally()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func copy(_ text: String, extraTypes: [NSPasteboard.PasteboardType] = []) {
        pasteboard.declareTypes([.string] + extraTypes, owner: nil)
        pasteboard.setString(text, forType: .string)
        for type in extraTypes {
            pasteboard.setData(Data(), forType: type)
        }
    }

    @Test func existingContentAtLaunchIsNotRecorded() {
        copy("before launch")
        _ = monitor
        monitor.checkNow()
        #expect(store.items.isEmpty)
    }

    @Test func recordsCopiesFromOtherApps() {
        _ = monitor
        copy("hello")
        monitor.checkNow()
        copy("https://folita.app")
        monitor.checkNow()

        #expect(store.items.map(\.title) == ["https://folita.app", "hello"])
        #expect(store.items.first?.sourceBundleID == "com.apple.TextEdit")
        #expect(store.items.first?.category == .link)
    }

    @Test func unchangedPasteboardIsNotRecordedTwice() {
        _ = monitor
        copy("once")
        monitor.checkNow()
        monitor.checkNow()
        #expect(store.items.count == 1)
    }

    @Test func recopyingMovesItemToTop() {
        _ = monitor
        for text in ["a", "b", "a"] {
            copy(text)
            monitor.checkNow()
        }
        #expect(store.items.map(\.title) == ["a", "b"])
    }

    @Test func skipsPasswordManagerAndOwnWrites() {
        _ = monitor
        copy("secret", extraTypes: [.concealed])
        monitor.checkNow()
        copy("written by folita", extraTypes: [.folitaOrigin])
        monitor.checkNow()
        #expect(store.items.isEmpty)
    }

    @Test func respectsPauseAndIgnoredApps() {
        _ = monitor
        privacy.isPaused = true
        copy("while paused")
        monitor.checkNow()

        privacy.isPaused = false
        privacy.ignore(bundleID: "com.example.bank")
        frontmost = "com.example.bank"
        copy("account number")
        monitor.checkNow()
        #expect(store.items.isEmpty)

        frontmost = "com.apple.Notes"
        copy("note")
        monitor.checkNow()
        #expect(store.items.map(\.title) == ["note"])
    }

    @Test func privacySettingsPersist() {
        privacy.isPaused = true
        privacy.ignore(bundleID: "com.example.bank")
        privacy.ignore(bundleID: "com.example.bank")

        let reloaded = PrivacySettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(reloaded.isPaused)
        #expect(reloaded.ignoredBundleIDs == ["com.example.bank"])

        reloaded.unignore(bundleID: "com.example.bank")
        #expect(reloaded.ignoredBundleIDs.isEmpty)
    }
}
