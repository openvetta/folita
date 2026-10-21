import AppKit
import Foundation
import Observation
import SwiftUI

/// 回填时写回剪贴板的方式。
enum PasteMode: Equatable, Sendable {
    /// 原样写回全部格式，保留富文本样式。
    case original
    /// 只写回纯文本。
    case plainText
}

/// 面板内键盘与菜单操作对应的命令。
enum ClipboardPanelCommand: Equatable {
    case moveUp
    case moveDown
    case paste(PasteMode)
    /// 直接回填当前列表中第 n 条（从 0 开始）。
    case pasteAt(Int)
    case deleteSelected
    case dismiss

    /// 面板内的固定按键。`⌘1`–`⌘9` 对应列表前 9 条。
    /// 说明页与按键提示使用的 `KeyEquivalent` 入口，统一转发到字符入口。
    static func command(for key: KeyEquivalent, modifiers: EventModifiers) -> ClipboardPanelCommand? {
        // `KeyEquivalent.delete` 的字符是退格 U+0008，而 AppKit 事件里 ⌫ 是 U+007F。
        command(for: key == .delete ? "\u{7F}" : String(key.character), modifiers: modifiers)
    }

    /// 以字符而非 `KeyEquivalent` 作为入口：AppKit 事件只给到字符，而 `KeyEquivalent(Character)`
    /// 对方向键等特殊字符的相等判断与静态常量不一致，字符串比对才可靠。
    static func command(for characters: String, modifiers: EventModifiers) -> ClipboardPanelCommand? {
        let modifiers = modifiers.intersection([.command, .shift, .option, .control])
        switch (characters, modifiers) {
        case (Key.upArrow, []): return .moveUp
        case (Key.downArrow, []): return .moveDown
        case (Key.return, []): return .paste(.original)
        case (Key.return, [.shift]): return .paste(.plainText)
        case (Key.delete, [.command]): return .deleteSelected
        case (Key.escape, []): return .dismiss
        case (_, [.command]):
            guard characters.count == 1, let digit = Int(characters), (1...9).contains(digit) else { return nil }
            return .pasteAt(digit - 1)
        default: return nil
        }
    }

    /// 从 AppKit 按键事件映射命令。搜索框聚焦时 TextField 会先吃掉方向键，
    /// 因此面板在窗口分发前用本地监视器拦一层，再走这里。
    static func command(for event: NSEvent) -> ClipboardPanelCommand? {
        guard event.type == .keyDown, let characters = event.charactersIgnoringModifiers else { return nil }
        return command(for: characters, modifiers: EventModifiers(event.modifierFlags))
    }

    /// 输入法正在组字时，方向键用于选词，不能被面板快捷键截走。
    static func isComposing(in responder: NSResponder?) -> Bool {
        (responder as? NSTextView)?.hasMarkedText() ?? false
    }

    /// 功能键在 `charactersIgnoringModifiers` 里的字符值。
    private enum Key {
        static let upArrow = "\u{F700}"
        static let downArrow = "\u{F701}"
        static let `return` = "\r"
        static let delete = "\u{7F}"
        static let escape = "\u{1B}"
    }
}

extension EventModifiers {
    /// 只保留面板快捷键关心的四个修饰键。
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}

/// 剪贴面板的界面状态：搜索、筛选与选中项。
@MainActor
@Observable
final class ClipboardPanelModel {
    var query = "" {
        didSet { selectedID = nil }
    }

    var filter: ClipboardFilter = .all {
        didSet { selectedID = nil }
    }

    /// 按 ID 记录选中项，面板打开期间有新复制进来时选中位置不跳动。
    private(set) var selectedID: UUID?

    /// 每次呼出面板递增，视图据此把焦点放回搜索框。
    private(set) var presentationCount = 0

    /// 呼出时刷新；授权状态可能在面板关闭期间被用户修改。
    private(set) var notice: PanelNotice = .none

    @ObservationIgnored let store: ClipboardHistoryStore
    @ObservationIgnored var onPaste: (HistoryItem, PasteMode) -> Void = { _, _ in }
    @ObservationIgnored var onDismiss: () -> Void = {}
    @ObservationIgnored var noticeProvider: () -> PanelNotice = { .none }
    @ObservationIgnored var onResolveNotice: (PanelNotice) -> Void = { _ in }
    /// 用户关掉的提示在本次运行期间不再出现；状态没修复的话下次启动会再次提示。
    @ObservationIgnored private var dismissedNotices: Set<PanelNotice> = []

    init(store: ClipboardHistoryStore) {
        self.store = store
    }

    var visibleItems: [HistoryItem] {
        Self.filter(store.items, filter: filter, query: query)
    }

    /// 未显式选中或选中项已不在列表中时，默认选中第一条。
    var selectedItem: HistoryItem? {
        let items = visibleItems
        return items.first { $0.id == selectedID } ?? items.first
    }

    /// 每次呼出面板时调用：清空搜索并回到第一条，保留用户选择的筛选类型。
    func prepareForPresentation() {
        query = ""
        selectedID = nil
        refreshNotice()
        presentationCount += 1
    }

    /// 授权状态可能在面板打开期间改变（例如从系统设置切回来）。
    func refreshNotice() {
        let current = noticeProvider()
        notice = dismissedNotices.contains(current) ? .none : current
    }

    func resolveNotice() {
        onResolveNotice(notice)
    }

    func dismissNotice() {
        dismissedNotices.insert(notice)
        notice = .none
    }

    func select(_ item: HistoryItem) {
        selectedID = item.id
    }

    func perform(_ command: ClipboardPanelCommand) {
        let items = visibleItems
        switch command {
        case .moveUp, .moveDown:
            guard let current = selectedItem, let index = items.firstIndex(where: { $0.id == current.id }) else { return }
            let next = command == .moveUp ? index - 1 : index + 1
            if items.indices.contains(next) {
                selectedID = items[next].id
            }
        case .paste(let mode):
            if let item = selectedItem {
                onPaste(item, mode)
            }
        case .pasteAt(let index):
            if items.indices.contains(index) {
                onPaste(items[index], .original)
            }
        case .deleteSelected:
            guard let item = selectedItem, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            // 删除后选中原位置的下一条，删的是最后一条则选中上一条。
            let neighbor = items.indices.contains(index + 1) ? items[index + 1] : (index > 0 ? items[index - 1] : nil)
            store.delete(item)
            selectedID = neighbor?.id
        case .dismiss:
            onDismiss()
        }
    }

    static func filter(_ items: [HistoryItem], filter: ClipboardFilter, query: String) -> [HistoryItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            filter.matches(item.category) && (query.isEmpty || item.title.localizedStandardContains(query))
        }
    }
}
