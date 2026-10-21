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
    /// 呼出面板时所在的应用，面板保持打开时 ⌘V 要直接投给它。
    private let targetProcessIdentifier: () -> pid_t?
    private let sendPasteKeystroke: @MainActor (PasteTarget) -> Void

    init(
        pasteboard: NSPasteboard = .general,
        store: ClipboardHistoryStore,
        settings: PasteSettings,
        accessibility: AccessibilityAccess = .system,
        targetProcessIdentifier: @escaping () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        sendPasteKeystroke: @escaping @MainActor (PasteTarget) -> Void = PasteKeystroke.post(to:)
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.settings = settings
        self.accessibility = accessibility
        self.targetProcessIdentifier = targetProcessIdentifier
        self.sendPasteKeystroke = sendPasteKeystroke
    }

    /// 调用前应先收起面板，让按键落到之前的应用上；`keepingPanelOpen` 为 true 时面板保持
    /// key window，⌘V 改为直接投递给目标应用。
    @discardableResult
    func paste(_ item: HistoryItem, mode: PasteMode, keepingPanelOpen: Bool = false) -> Outcome {
        ClipboardWriter.write(item.clipContents, mode: mode, to: pasteboard)
        store.touch(item)
        guard settings.autoPaste, accessibility.isTrusted() else { return .copied }
        sendPasteKeystroke(keepingPanelOpen ? targetApplication() : .keyWindow)
        return .pasted
    }

    private func targetApplication() -> PasteTarget {
        guard let pid = targetProcessIdentifier() else { return .keyWindow }
        return .process(pid)
    }
}

/// ⌘V 的送达方式。
enum PasteTarget: Equatable, Sendable {
    /// 面板已收起：交给当前键盘焦点，也就是原来的应用。
    case keyWindow
    /// 面板保持打开：面板仍是 key window，⌘V 直接投递给目标应用自己的事件队列。
    case process(pid_t)
}

enum PasteKeystroke {
    /// 发送 ⌘V。稍作延迟，等面板收起后焦点回到之前的应用。
    @MainActor
    static func post(to target: PasteTarget = .keyWindow) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            for isKeyDown in [true, false] {
                // 9 是 ANSI 键盘上 V 的键位；同时写入字符 "v"，非 QWERTY 布局下应用按字符匹配快捷键。
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: isKeyDown) else { continue }
                event.flags = .maskCommand
                var character: UniChar = 0x76
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
                switch target {
                case .keyWindow:
                    event.post(tap: .cgSessionEventTap)
                case .process(let pid):
                    event.postToPid(pid)
                }
            }
        }
    }
}
