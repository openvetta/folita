import AppKit
import ApplicationServices

/// 辅助功能授权。自动粘贴需要它才能向其他应用发送按键。
struct AccessibilityAccess {
    var isTrusted: @MainActor () -> Bool
    /// 弹出系统授权提示并把应用加入授权列表。
    var requestAccess: @MainActor () -> Void

    static let system = AccessibilityAccess(
        isTrusted: { AXIsProcessTrusted() },
        requestAccess: {
            // 即 kAXTrustedCheckOptionPrompt 的值；该常量是 C 全局变量，Swift 6 严格并发下不能直接引用。
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    )
}

/// 把选中的历史回填到之前的应用（见 docs/adr/0001）。
@MainActor
final class PasteService {
    enum Outcome: Equatable {
        /// 已写回剪贴板并发送 ⌘V。
        case pasted
        /// 只写回了剪贴板：自动粘贴已关闭或缺少辅助功能授权。
        case copied
    }

    private let pasteboard: NSPasteboard
    private let store: ClipboardHistoryStore
    private let settings: PasteSettings
    private let accessibility: AccessibilityAccess
    private let sendPasteKeystroke: @MainActor () -> Void

    init(
        pasteboard: NSPasteboard = .general,
        store: ClipboardHistoryStore,
        settings: PasteSettings,
        accessibility: AccessibilityAccess = .system,
        sendPasteKeystroke: @escaping @MainActor () -> Void = PasteKeystroke.post
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.settings = settings
        self.accessibility = accessibility
        self.sendPasteKeystroke = sendPasteKeystroke
    }

    /// 调用前应先收起面板，让按键落到之前的应用上。
    @discardableResult
    func paste(_ item: HistoryItem, mode: PasteMode) -> Outcome {
        ClipboardWriter.write(item.clipContents, mode: mode, to: pasteboard)
        store.touch(item)
        guard settings.autoPaste, accessibility.isTrusted() else { return .copied }
        sendPasteKeystroke()
        return .pasted
    }
}

enum PasteKeystroke {
    /// 发送 ⌘V。稍作延迟，等面板收起后焦点回到之前的应用。
    @MainActor
    static func post() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            for isKeyDown in [true, false] {
                // 9 是 ANSI 键盘上 V 的键位；同时写入字符 "v"，非 QWERTY 布局下应用按字符匹配快捷键。
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: isKeyDown) else { continue }
                event.flags = .maskCommand
                var character: UniChar = 0x76
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
                event.post(tap: .cgSessionEventTap)
            }
        }
    }
}
