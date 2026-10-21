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

    /// 只复制了图片文件（微信式，无图片数据）：采集时读入文件内容，之后文件不可读也能显示缩略图。
    @Test func copiedImageFileIsSnapshottedAtCaptureTime() async throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 20, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        let url = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = monitor
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([url as NSURL]))
        monitor.checkNow()

        let item = try #require(store.items.first)
        #expect(item.category == .file)
        #expect(item.clipContents.contains { $0.type == .png })

        try FileManager.default.removeItem(at: url)
        #expect(await ClipPreviewImages.thumbnail(for: item, maxPixelSize: 40)?.width == 40)
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
