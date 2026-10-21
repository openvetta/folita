import AppKit
import SwiftData
import Testing
@testable import Folita

/// 从选中历史到写回剪贴板、发送 ⌘V 的回填流程。使用唯一命名的剪贴板，不触碰系统剪贴板。
@MainActor
final class PasteServiceTests {
    private let pasteboard = NSPasteboard(name: .init("FolitaTests.Paste.\(UUID().uuidString)"))
    private let suiteName = "FolitaTests.Paste.\(UUID().uuidString)"
    private let settings: PasteSettings
    private let store: ClipboardHistoryStore
    private var trusted = true
    /// 每次 ⌘V 的送达方式。
    private var keystrokes: [PasteTarget] = []
    /// 呼出面板时所在应用的进程号；nil 表示读不到。
    private var targetPID: pid_t? = 4242

    init() {
        settings = PasteSettings(userDefaults: UserDefaults(suiteName: suiteName)!)
        store = ClipboardHistoryStore(container: HistoryStorage.makeInMemoryContainer(), limit: { 500 })
    }

    isolated deinit {
        pasteboard.releaseGlobally()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeService() -> PasteService {
        PasteService(
            pasteboard: pasteboard,
            store: store,
            settings: settings,
            accessibility: AccessibilityAccess(isTrusted: { [unowned self] in trusted }, requestAccess: {}),
            targetProcessIdentifier: { [unowned self] in targetPID },
            sendPasteKeystroke: { [unowned self] target in keystrokes.append(target) }
        )
    }

    private func record(_ contents: [ClipContent]) -> HistoryItem {
        store.record(CapturedClip(contents: contents, sourceBundleID: nil))
        return store.items[0]
    }

    private let richContents = [
        ClipContent(type: .string, data: Data("Bold".utf8)),
        ClipContent(type: .rtf, data: NSAttributedString(string: "Bold").rtf(from: NSRange(location: 0, length: 4))!),
    ]

    @Test func pastesAllFormatsAndSendsKeystroke() {
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original) == .pasted)
        // 面板已收起：⌘V 仍交给当前键盘焦点。
        #expect(keystrokes == [.keyWindow])
        #expect(pasteboard.string(forType: .string) == "Bold")
        #expect(pasteboard.data(forType: .rtf) == richContents[1].data)
        #expect(pasteboard.types?.contains(.folitaOrigin) == true)
    }

    /// ⌥↩：面板保持 key window，⌘V 必须直接投递给呼出面板时的那个应用。
    @Test func keepingPanelOpenSendsKeystrokeToTheTargetApp() {
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original, keepingPanelOpen: true) == .pasted)
        #expect(keystrokes == [.process(4242)])
        #expect(pasteboard.string(forType: .string) == "Bold")
    }

    /// 读不到目标应用时退回正常送达，而不是不发按键。
    @Test func keepingPanelOpenFallsBackWithoutATargetApp() {
        targetPID = nil
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original, keepingPanelOpen: true) == .pasted)
        #expect(keystrokes == [.keyWindow])
    }

    /// 缺少辅助功能授权时保持面板打开也只写回剪贴板。
    @Test func keepingPanelOpenStillNeedsAuthentication() {
        trusted = false
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original, keepingPanelOpen: true) == .copied)
        #expect(keystrokes.isEmpty)
    }

    @Test func plainTextModeDropsFormatting() {
        let item = record(richContents)
        makeService().paste(item, mode: .plainText)

        #expect(pasteboard.string(forType: .string) == "Bold")
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    @Test func plainTextIsExtractedFromRichTextOnlyClips() {
        let rtfOnly = [richContents[1]]
        #expect(ClipboardWriter.plainText(from: rtfOnly) == "Bold")
        #expect(ClipboardWriter.plainText(from: [ClipContent(type: .png, data: Data([1]))]) == nil)
    }

    @Test func multipleFilesAreWrittenAsSeparateItems() {
        let a = URL(filePath: "/tmp/a.txt"), b = URL(filePath: "/tmp/b.txt")
        let item = record([
            ClipContent(type: .fileURL, data: a.dataRepresentation),
            ClipContent(type: .fileURL, data: b.dataRepresentation),
        ])
        makeService().paste(item, mode: .original)

        let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        #expect(urls == [a, b])
    }

    @Test func fallsBackToCopyWithoutAccessibility() {
        trusted = false
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original) == .copied)
        #expect(keystrokes.isEmpty)
        #expect(pasteboard.string(forType: .string) == "Bold")
    }

    @Test func autoPasteCanBeTurnedOff() {
        settings.autoPaste = false
        let item = record(richContents)

        #expect(makeService().paste(item, mode: .original) == .copied)
        #expect(keystrokes.isEmpty)
        #expect(PasteSettings(userDefaults: UserDefaults(suiteName: suiteName)!).autoPaste == false)
    }

    @Test func pastedItemMovesToTopAndIsNotRecordedAgain() {
        let older = record([ClipContent(type: .string, data: Data("older".utf8))])
        _ = record([ClipContent(type: .string, data: Data("newer".utf8))])
        let monitor = ClipboardMonitor(pasteboard: pasteboard, privacy: PrivacySettings(
            userDefaults: UserDefaults(suiteName: suiteName)!
        )) { [store] in store.record($0) }

        makeService().paste(older, mode: .original)
        monitor.checkNow()

        #expect(store.items.map(\.title) == ["older", "newer"])
    }

    @Test func defaultsToAutoPaste() {
        #expect(settings.autoPaste)
    }
}
