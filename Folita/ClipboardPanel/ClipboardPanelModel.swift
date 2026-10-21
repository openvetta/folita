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
    /// 粘贴到之前的应用但保持面板打开（⌥↩），方便连续粘贴多条。
    case pasteKeepingPanelOpen
    /// 直接回填当前列表中第 n 条（从 0 开始）。
    case pasteAt(Int)
    case deleteSelected
    case deleteAll
    /// 用默认浏览器打开链接条目。
    case openInBrowser
    /// 给指定邮件地址写信。
    case composeEmail(String)
    /// 把颜色条目转换成另一种格式并粘贴。
    case convertColor(ColorFormat)
    /// 打开或收起选中项的「更多操作」菜单（⌘K，右键也能打开）。
    case toggleActionsMenu
    /// 打开主面板（⌘,），与菜单栏的「Open Main Panel」一致。
    case openMainPanel
    /// 打开详情预览（peek）：面板加宽，右侧显示选中项详情。
    case peek
    /// 收起详情预览，面板恢复原宽度。
    case endPeek
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
        case (Key.rightArrow, []): return .peek
        case (Key.leftArrow, []): return .endPeek
        case (Key.return, []): return .paste(.original)
        case (Key.return, [.shift]): return .paste(.plainText)
        case (Key.return, [.option]): return .pasteKeepingPanelOpen
        case (Key.delete, [.command]): return .deleteSelected
        case ("x", [.control]): return .deleteSelected
        case ("x", [.control, .shift]): return .deleteAll
        case ("k", [.command]): return .toggleActionsMenu
        case (",", [.command]): return .openMainPanel
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

    /// 事件中可直接作为搜索词输入的文字；带 ⌘ / ⌃ 的组合键、方向键等功能键返回 nil。
    static func typedText(for event: NSEvent) -> String? {
        guard event.type == .keyDown, event.modifierFlags.isDisjoint(with: [.command, .control]),
              let text = event.characters, !text.isEmpty,
              text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) })
        else { return nil }
        return text
    }

    /// 输入法正在组字时，方向键用于选词，不能被面板快捷键截走。
    static func isComposing(in responder: NSResponder?) -> Bool {
        (responder as? NSTextView)?.hasMarkedText() ?? false
    }

    /// ← → 同时是搜索框里移动光标的键，只在不打断编辑时由面板接管：
    /// → 在光标停在搜索词末尾（光标本就无处可去）或预览已打开时进入预览；← 只在预览打开时用于退出。
    func isIntercepted(isPeeking: Bool, responder: NSResponder?) -> Bool {
        switch self {
        case .peek: isPeeking || Self.isCaretAtEnd(in: responder)
        case .endPeek: isPeeking
        default: true
        }
    }

    /// 焦点不在文本编辑器里时视为光标在末尾。
    static func isCaretAtEnd(in responder: NSResponder?) -> Bool {
        guard let editor = responder as? NSTextView else { return true }
        let selection = editor.selectedRange()
        return selection.length == 0 && selection.location == (editor.string as NSString).length
    }

    /// 功能键在 `charactersIgnoringModifiers` 里的字符值。
    private enum Key {
        static let upArrow = "\u{F700}"
        static let downArrow = "\u{F701}"
        static let leftArrow = "\u{F702}"
        static let rightArrow = "\u{F703}"
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

/// 剪贴面板的界面状态：搜索、筛选、选中项与详情预览（peek）。
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

    /// 「更多操作」菜单锚定在哪一条上；nil 表示菜单未打开。锚在条目而不是行位置上，
    /// 列表重排或滚动时卡片跟着那一行走。
    private(set) var actionsMenuItemID: UUID?

    /// 菜单里高亮第几项，↑↓ 改它、↩ 执行它，鼠标悬停也同步。
    private(set) var actionsMenuIndex = 0

    /// 菜单打开时锚定条目对应的条目列表，打开时按内容算一次，期间不随渲染重算。
    private(set) var actionsMenuEntries: [ClipboardActionsMenuEntry] = []

    /// 已就地展开二级菜单的条目。
    private(set) var actionsMenuExpanded: ClipboardActionsMenuEntry?

    /// 各历史行在容器坐标系（原点在容器左上角）中的位置，由列表在布局后写回。
    /// 菜单定位与右键命中都靠它。
    private(set) var rowFrames: [UUID: CGRect] = [:]

    /// 呼出面板时那个前台应用的名字，用作「粘贴到 XXX」的菜单标题。
    private(set) var targetAppName: String?

    /// 是否处于详情预览。预览是一种浏览模式而非弹窗：上下键、搜索、筛选、删除都只换右侧
    /// 显示的条目，只有 ← 会退出；每次重新呼出面板时复位。
    private(set) var isPeeking = false {
        didSet {
            if isPeeking != oldValue { onPeekChange(isPeeking) }
        }
    }

    /// 每次呼出面板时递增。
    private(set) var presentationCount = 0

    /// 每次需要把焦点放回搜索框时递增（呼出、焦点不在搜索框时直接打字），视图据此聚焦。
    private(set) var searchFocusRequest = 0

    /// 呼出时刷新；授权状态可能在面板关闭期间被用户修改。
    private(set) var notice: PanelNotice = .none

    @ObservationIgnored let store: ClipboardHistoryStore
    @ObservationIgnored var onPaste: (HistoryItem, PasteMode) -> Void = { _, _ in }
    /// ⌥↩：粘贴到之前的应用并保持面板打开；由宿主装配（不收起面板，直接把 ⌘V 投给目标应用）。
    @ObservationIgnored var onPasteKeepingPanelOpen: (HistoryItem, PasteMode) -> Void = { _, _ in }
    /// 呼出面板时的前台应用名；测试里替换为固定值。
    @ObservationIgnored var targetAppNameProvider: () -> String? = {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
    /// 在访达中显示文件；由宿主装配（收起面板并调用系统接口）。
    @ObservationIgnored var onRevealInFinder: ([URL]) -> Void = { _ in }
    /// 用系统默认应用打开网址（http(s) 链接与 mailto）；由宿主装配（收起面板并调用系统接口）。
    @ObservationIgnored var onOpenURL: (URL) -> Void = { _ in }
    /// 收起面板，把转换后的文本写回剪贴板并粘贴到之前的应用；由宿主装配。
    @ObservationIgnored var onPasteText: (String) -> Void = { _ in }
    /// 打开主面板（⌘,）；由宿主装配（收起面板并打开主面板窗口）。
    @ObservationIgnored var onOpenMainPanel: () -> Void = {}
    @ObservationIgnored var onDismiss: () -> Void = {}
    @ObservationIgnored var noticeProvider: () -> PanelNotice = { .none }
    @ObservationIgnored var onResolveNotice: (PanelNotice) -> Void = { _ in }
    /// 进入或退出详情预览时通知宿主窗口调整宽度。
    @ObservationIgnored var onPeekChange: (Bool) -> Void = { _ in }
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
        isPeeking = false
        actionsMenuItemID = nil
        targetAppName = targetAppNameProvider()
        refreshNotice()
        presentationCount += 1
        searchFocusRequest += 1
    }

    /// 焦点不在搜索框时用户直接打字：文字并入搜索词，并把焦点交还搜索框。
    func typeIntoSearch(_ text: String) {
        query += text
        searchFocusRequest += 1
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

    /// 详情中的「从访达打开」：只对带文件的条目生效。
    func openInFinder(_ item: HistoryItem) {
        guard let urls = ClipClassification.fileURLs(in: item.clipContents) else { return }
        onRevealInFinder(urls)
    }

    func select(_ item: HistoryItem) {
        selectedID = item.id
    }

    // MARK: 更多操作菜单

    var isShowingActionsMenu: Bool { actionsMenuItemID != nil }

    /// 菜单当前展开的行：固定条目与按内容出现的条目，加上展开条目的二级条目（紧跟在父条目后），
    /// 键盘 ↑↓ 按这个顺序移动。
    var actionsMenuRows: [ClipboardActionsMenuRow] {
        ClipboardActionsMenuRow.rows(of: actionsMenuEntries, expanded: actionsMenuExpanded)
    }

    /// 一级卡片里的行，与展开的二级条目分开画。
    var actionsMenuTopRows: [ClipboardActionsMenuRow] { actionsMenuRows.filter { $0.depth == 0 } }
    var actionsMenuChildRows: [ClipboardActionsMenuRow] { actionsMenuRows.filter { $0.depth == 1 } }

    private var actionsMenuContainer: CGRect {
        CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize(isPeeking: isPeeking))
    }

    /// 一级菜单卡片在容器坐标中的位置；还没量到那一行时返回 nil，菜单等布局完成后再出现。
    var actionsMenuFrame: CGRect? {
        guard let actionsMenuItemID, let row = rowFrames[actionsMenuItemID] else { return nil }
        let rows = actionsMenuTopRows
        return ClipboardPanelMetrics.actionsMenuFrame(
            anchoredTo: row,
            size: ClipboardPanelMetrics.actionsMenuSize(
                rowCount: rows.count,
                separatorCount: ClipboardActionsMenuRow.separatorCount(in: rows)
            ),
            in: actionsMenuContainer
        )
    }

    /// 二级菜单卡片的位置；没有展开的二级菜单时为 nil。
    var actionsSubmenuFrame: CGRect? {
        guard let menu = actionsMenuFrame, let expanded = actionsMenuExpanded else { return nil }
        let top = actionsMenuTopRows
        guard let index = top.firstIndex(where: { $0.entry == expanded }) else { return nil }
        let children = actionsMenuChildRows
        guard !children.isEmpty else { return nil }
        let separatorsBefore = ClipboardActionsMenuRow.separatorCount(in: Array(top[...index]))
        return ClipboardPanelMetrics.actionsSubmenuFrame(
            besides: menu,
            parentRowOffset: ClipboardPanelMetrics.actionsMenuRowOffset(index: index, separatorsBefore: separatorsBefore),
            rowCount: children.count,
            in: actionsMenuContainer
        )
    }

    /// 点在任一菜单卡片上。
    func actionsMenuContains(_ point: CGPoint) -> Bool {
        actionsMenuFrame?.contains(point) == true || actionsSubmenuFrame?.contains(point) == true
    }

    /// 菜单里当前高亮的条目，↑↓ 移动，↩ 执行。
    var highlightedActionsMenuEntry: ClipboardActionsMenuEntry? {
        let rows = actionsMenuRows
        return rows.indices.contains(actionsMenuIndex) ? rows[actionsMenuIndex].entry : nil
    }

    /// 右键或 ⌘K 打开：菜单锚在选中条目上，条目按它的内容决定，高亮回到第一项。
    func showActions(for item: HistoryItem) {
        selectedID = item.id
        actionsMenuItemID = item.id
        actionsMenuEntries = ClipboardActionsMenuEntry.entries(for: details(of: item))
        actionsMenuExpanded = nil
        actionsMenuIndex = 0
    }

    func hideActions() {
        actionsMenuItemID = nil
        actionsMenuEntries = []
        actionsMenuExpanded = nil
        actionsMenuIndex = 0
    }

    /// ↑↓：在菜单项之间移动，到头就停住，不回绕。
    func moveActionsMenuSelection(by offset: Int) {
        guard isShowingActionsMenu else { return }
        let count = actionsMenuRows.count
        actionsMenuIndex = min(max(actionsMenuIndex + offset, 0), count - 1)
    }

    /// 鼠标悬停到某一项上：高亮跟过去，↩ 执行的就是它。
    func highlightActionsMenuEntry(_ entry: ClipboardActionsMenuEntry) {
        guard isShowingActionsMenu,
              let index = actionsMenuRows.firstIndex(where: { $0.entry == entry })
        else { return }
        actionsMenuIndex = index
    }

    /// ↩ 执行当前高亮项。
    func confirmActionsMenuSelection() {
        guard let entry = highlightedActionsMenuEntry else { return }
        activateActionsMenuEntry(entry)
    }

    /// 点击或 ↩ 一行：带二级菜单的条目就地展开 / 收回，其余执行命令（先收起菜单，粘贴动作本身可能再收起面板）。
    func activateActionsMenuEntry(_ entry: ClipboardActionsMenuEntry) {
        guard isShowingActionsMenu else { return }
        if !entry.children.isEmpty {
            actionsMenuExpanded = actionsMenuExpanded == entry ? nil : entry
            highlightActionsMenuEntry(entry)
        } else if let command = entry.command {
            perform(command)
        }
    }

    /// →：展开高亮的带二级菜单的条目，高亮落到它的第一个二级条目上。
    func expandActionsMenuSelection() {
        guard let entry = highlightedActionsMenuEntry, !entry.children.isEmpty, actionsMenuExpanded != entry else { return }
        actionsMenuExpanded = entry
        actionsMenuIndex = min(actionsMenuIndex + 1, actionsMenuRows.count - 1)
    }

    /// ← / Esc：有展开的二级菜单就先收回并让高亮回到父条目；否则关闭菜单。返回是否只是收回了二级菜单。
    @discardableResult
    func backOutOfActionsMenu() -> Bool {
        guard let parent = actionsMenuExpanded else {
            hideActions()
            return false
        }
        actionsMenuExpanded = nil
        highlightActionsMenuEntry(parent)
        return true
    }

    // MARK: 内容相关的操作

    private func details(of item: HistoryItem) -> ClipDetails {
        ClipDetails(contents: item.clipContents, category: item.category)
    }

    /// 详情或菜单里的「浏览器打开」：只对链接条目生效。
    func openInBrowser(_ item: HistoryItem) {
        guard let url = details(of: item).link else { return }
        onOpenURL(url)
    }

    func composeEmail(to address: String) {
        guard let url = EmailAddresses.mailtoURL(to: address) else { return }
        onOpenURL(url)
    }

    /// 把颜色条目转换成指定格式并粘贴；不是颜色条目时不做任何事。
    func convertColor(of item: HistoryItem, to format: ColorFormat) {
        guard let color = details(of: item).color else { return }
        onPasteText(format.string(for: color))
    }

    func setRowFrame(_ frame: CGRect, for id: UUID) {
        guard rowFrames[id] != frame else { return }
        rowFrames[id] = frame
    }

    /// 容器坐标中命中哪一条历史；点在行间空隙或列表外时返回 nil。
    func item(at point: CGPoint) -> HistoryItem? {
        visibleItems.first { rowFrames[$0.id]?.contains(point) ?? false }
    }

    func perform(_ command: ClipboardPanelCommand) {
        switch command {
        case .toggleActionsMenu:
            toggleActionsMenu()
            return
        case .dismiss where isShowingActionsMenu:
            // 菜单打开时 Esc 先收回二级菜单、再收起菜单，最后一次才收起面板。
            backOutOfActionsMenu()
            return
        case .moveUp where isShowingActionsMenu:
            moveActionsMenuSelection(by: -1)
            return
        case .moveDown where isShowingActionsMenu:
            moveActionsMenuSelection(by: 1)
            return
        case .paste(.original) where isShowingActionsMenu:
            confirmActionsMenuSelection()
            return
        default:
            // 其他命令不经过菜单：先收起菜单再执行。
            if isShowingActionsMenu { hideActions() }
        }

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
        case .pasteKeepingPanelOpen:
            if let item = selectedItem {
                onPasteKeepingPanelOpen(item, .original)
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
        case .openInBrowser:
            if let item = selectedItem { openInBrowser(item) }
        case .composeEmail(let address):
            composeEmail(to: address)
        case .convertColor(let format):
            if let item = selectedItem { convertColor(of: item, to: format) }
        case .deleteAll:
            store.clearAll()
            selectedID = nil
        case .peek:
            // 列表为空时没有可看的内容，不进入预览。
            if selectedItem != nil {
                isPeeking = true
            }
        case .endPeek:
            isPeeking = false
        case .openMainPanel:
            onOpenMainPanel()
        case .dismiss:
            onDismiss()
        case .toggleActionsMenu:
            // 菜单命令已在上面处理完，不会走到这里。
            break
        }
    }

    private func toggleActionsMenu() {
        guard !isShowingActionsMenu else {
            hideActions()
            return
        }
        if let item = selectedItem {
            showActions(for: item)
        }
    }

    static func filter(_ items: [HistoryItem], filter: ClipboardFilter, query: String) -> [HistoryItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            filter.matches(item.category) && (query.isEmpty || item.title.localizedStandardContains(query))
        }
    }
}
