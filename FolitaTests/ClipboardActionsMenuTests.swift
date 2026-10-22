import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardActionsMenuTests {
    nonisolated private static let appearances: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private static let container = CGRect(origin: .zero, size: ClipboardPanelMetrics.containerSize)
    /// 纯文本条目的菜单：只有固定的粘贴与删除条目。
    private static let entries = ClipboardActionsMenuEntry.entries(for: ClipDetails(
        contents: [ClipContent(type: .string, data: Data("a".utf8))], category: .text
    ))
    private static let entryCount = entries.count

    // MARK: 布局

    /// 卡片高度＝内边距 × 2 + 条目 × 行高 + 一道分组分割线。
    @Test func menuSizeFollowsEntryCount() {
        let size = ClipboardPanelMetrics.actionsMenuSize(rowCount: 5, separatorCount: 1)
        #expect(size.width == ClipboardPanelMetrics.actionsMenuWidth)
        #expect(
            size.height
                == ClipboardPanelMetrics.actionsMenuPadding * 2
                + 5 * ClipboardPanelMetrics.actionsMenuEntryHeight
                + ClipboardPanelMetrics.actionsMenuSeparatorHeight
        )
    }

    /// 默认贴在那一行的下方，并与行右对齐。
    @Test func menuSitsBelowTheRow() {
        let row = CGRect(x: 24, y: 100, width: 392, height: 52)
        let frame = ClipboardPanelMetrics.actionsMenuFrame(anchoredTo: row, size: ClipboardPanelMetrics.actionsMenuSize(rowCount: 5, separatorCount: 1), in: Self.container)

        #expect(frame.maxX == row.maxX)
        #expect(frame.minY == row.maxY + ClipboardPanelMetrics.actionsMenuGap)
        #expect(Self.container.contains(frame))
    }

    /// 下方放不下时翻到行的上方，不越过容器底边。
    @Test func menuFlipsAboveTheRowNearTheBottom() {
        let row = CGRect(x: 24, y: 460, width: 392, height: 52)
        let frame = ClipboardPanelMetrics.actionsMenuFrame(anchoredTo: row, size: ClipboardPanelMetrics.actionsMenuSize(rowCount: 5, separatorCount: 1), in: Self.container)

        #expect(frame.maxY == row.minY - ClipboardPanelMetrics.actionsMenuGap)
        #expect(frame.minY >= Self.container.minY)
    }

    /// 行超出左右边界时卡片向内夹，整张卡片始终在容器内。
    @Test func menuStaysInsideTheContainer() {
        let wide = CGRect(x: 200, y: 100, width: 400, height: 52)
        let right = ClipboardPanelMetrics.actionsMenuFrame(anchoredTo: wide, size: ClipboardPanelMetrics.actionsMenuSize(rowCount: 5, separatorCount: 1), in: Self.container)
        #expect(right.maxX == Self.container.maxX - ClipboardPanelMetrics.actionsMenuInset)

        let narrow = CGRect(x: 0, y: 100, width: 10, height: 52)
        let left = ClipboardPanelMetrics.actionsMenuFrame(anchoredTo: narrow, size: ClipboardPanelMetrics.actionsMenuSize(rowCount: 5, separatorCount: 1), in: Self.container)
        #expect(left.minX == Self.container.minX + ClipboardPanelMetrics.actionsMenuInset)
    }

    /// 窗口坐标（原点在左下）与容器坐标（原点在左上、去掉透明边距）互换。
    @Test func windowPointMapsIntoContainerCoordinates() {
        let windowHeight = ClipboardPanelMetrics.windowSize.height
        let inset = ClipboardPanelMetrics.shadowInset

        // 容器左上角在窗口坐标里是 (28, 窗口高 - 28)。
        #expect(
            ClipboardPanelMetrics.containerPoint(
                fromWindow: CGPoint(x: inset, y: windowHeight - inset),
                windowHeight: windowHeight
            ) == .zero
        )
        #expect(
            ClipboardPanelMetrics.containerPoint(
                fromWindow: CGPoint(x: inset + 40, y: windowHeight - inset - 90),
                windowHeight: windowHeight
            ) == CGPoint(x: 40, y: 90)
        )
    }

    // MARK: 条目

    /// 菜单上标出的键必须真能触发同一动作：改键位时两边要一起改。
    @Test func shortcutGlyphsMatchTheirKeyBindings() {
        for entry in Self.entries {
            let (characters, modifiers) = Self.parse(entry.shortcut)
            #expect(ClipboardPanelCommand.command(for: characters, modifiers: modifiers) == entry.command)
        }
    }

    @Test func entriesAreGroupedWithDeleteLast() {
        // 收藏独立成组（2），删除组因此后移为 3。
        #expect(Self.entries.map(\.group) == [0, 0, 0, 2, 3, 3])
        #expect(Self.entries.filter(\.isDestructive) == [.deleteEntry, .deleteAll])
        #expect(
            Self.entries.map(\.command) == [
                .paste(.original), .pasteKeepingPanelOpen, .paste(.plainText),
                .toggleFavoritePicker, .deleteSelected, .deleteAll,
            ]
        )
    }

    /// 「粘贴到 XXX」带上呼出面板时那个应用的名字，读不到时退回「粘贴」。
    @Test func pasteToTargetUsesTheAppName() {
        // 类型上下文不可推断（localized 的入参是 LocalizedStringResource），显式写出条目类型。
        let name: String? = "Safari"
        let entry = ClipboardActionsMenuEntry.pasteToTarget
        #expect(Self.title(entry, name, "en") == "Paste to Safari")
        #expect(Self.title(entry, name, "zh-Hans") == "粘贴到 Safari")
        #expect(Self.title(entry, nil, "zh-Hans") == "粘贴")
    }

    @Test func entryTitlesAreLocalized() {
        let titles: [(ClipboardActionsMenuEntry, String, String)] = [
            (.pasteKeepingPanelOpen, "Paste and Keep Window Open", "粘贴并保持窗口打开"),
            (.pasteAsPlainText, "Paste as Plain Text", "以纯文本粘贴"),
            (.deleteEntry, "Delete Entry", "删除此条"),
            (.deleteAll, "Delete All Entries", "删除全部"),
        ]
        for (entry, en, zh) in titles {
            #expect(Self.title(entry, nil, "en") == en)
            #expect(Self.title(entry, nil, "zh-Hans") == zh)
        }
    }

    // MARK: 卡片

    /// 卡片按 `actionsMenuSize` 算出的尺寸完成布局，深浅色与中英文都一样。
    @Test(arguments: appearances)
    func menuCardLaysOutAtTheComputedSize(locale: String, scheme: ColorScheme) {
        // 面板按算出的尺寸给卡片定宽，这里断言两边一致。
        // 收藏与删除各成一组，分割线因此是两道。
        let size = ClipboardPanelMetrics.actionsMenuSize(rowCount: Self.entryCount, separatorCount: 2)
        let host = NSHostingView(
            rootView: ClipboardActionsMenuView(
                rows: ClipboardActionsMenuRow.rows(of: Self.entries, expanded: nil),
                targetAppName: "Safari",
                highlighted: nil,
                expanded: nil,
                activate: { _ in }
            )
                .frame(width: size.width)
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize == size)
    }

    // MARK: 键与鼠标

    /// ⌘K 打开菜单、再按收起；Esc 先收起菜单，再按才收起面板。
    @Test func commandKOpensAndEscapeClosesTheMenu() throws {
        let model = makePanelModel(copying: ["b", "a"])
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try Self.key("k", .command)))
        #expect(model.isShowingActionsMenu)
        #expect(model.actionsMenuFrame != nil)

        #expect(controller.handleKeyDown(try Self.key("\u{1B}")))
        #expect(model.isShowingActionsMenu == false)
        #expect(controller.isVisible)

        #expect(controller.handleKeyDown(try Self.key("\u{1B}")))
        #expect(controller.isVisible == false)
    }

    /// 右键条目：选中被点的那一条，并把菜单锚在它上面。
    @Test func rightClickOpensTheMenuForTheClickedRow() throws {
        let model = makePanelModel(copying: ["c", "b", "a"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        let items = model.visibleItems
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: items[0].id)
        model.setRowFrame(CGRect(x: 24, y: 144, width: 392, height: 52), for: items[1].id)

        #expect(controller.handleMouseDown(at: CGPoint(x: 100, y: 160), isRightClick: true))
        #expect(model.selectedItem?.id == items[1].id)
        #expect(model.actionsMenuItemID == items[1].id)
    }

    /// 右键点空处（行间空隙、搜索框）：收起菜单，选中项不变，右键不消费（搜索框仍可用系统菜单）。
    @Test func rightClickOutsideAnyRowOnlyClosesTheMenu() throws {
        let model = makePanelModel(copying: ["c", "b", "a"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        let first = try #require(model.visibleItems.first)
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: first.id)
        model.showActions(for: first)
        #expect(model.isShowingActionsMenu)

        #expect(controller.handleMouseDown(at: CGPoint(x: 100, y: 400), isRightClick: true) == false)
        #expect(model.isShowingActionsMenu == false)
        #expect(model.selectedItem?.id == first.id)
    }

    /// 菜单打开时点卡片以外：只收起菜单，不把这一下当成点条目（否则会误粘贴并收起面板）。
    @Test func clickOutsideTheMenuCardOnlyClosesTheMenu() throws {
        let model = makePanelModel(copying: ["c", "b", "a"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        let first = try #require(model.visibleItems.first)
        let row = CGRect(x: 24, y: 88, width: 392, height: 52)
        model.setRowFrame(row, for: first.id)
        model.showActions(for: first)
        let card = try #require(model.actionsMenuFrame)

        #expect(controller.handleMouseDown(at: CGPoint(x: card.maxX + 20, y: row.midY), isRightClick: false))
        #expect(model.isShowingActionsMenu == false)
        #expect(controller.isVisible)
    }

    /// 点在卡片上交给 SwiftUI 的按钮处理，控制器不消费。
    @Test func clickInsideTheMenuCardReachesItsButtons() throws {
        let model = makePanelModel(copying: ["a"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        let first = try #require(model.visibleItems.first)
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: first.id)
        model.showActions(for: first)
        let card = try #require(model.actionsMenuFrame)

        #expect(controller.handleMouseDown(at: CGPoint(x: card.midX, y: card.midY), isRightClick: false) == false)
        #expect(model.isShowingActionsMenu)
    }

    /// 菜单没打开时左键完全交还给列表（单击即粘贴）。
    @Test func clickPassesThroughWhenTheMenuIsClosed() throws {
        let controller = ClipboardPanelController(model: makePanelModel(copying: ["a"]), placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleMouseDown(at: CGPoint(x: 100, y: 100), isRightClick: false) == false)
    }

    // MARK: 菜单内的键盘操作

    /// 常见流程：⌘K 打开菜单（高亮第一项）→ ↓↓↓↓ 移到「删除此条」→ ↩ 执行 → 菜单关闭且条目被删。
    @Test func menuIsDrivenByArrowKeysAndReturn() throws {
        let model = makePanelModel(copying: ["b", "a"])
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try Self.key("k", .command)))
        #expect(model.highlightedActionsMenuEntry == .pasteToTarget)

        for _ in 0..<4 { #expect(controller.handleKeyDown(try Self.key("\u{F701}"))) }
        #expect(model.highlightedActionsMenuEntry == .deleteEntry)

        #expect(controller.handleKeyDown(try Self.key("\r")))
        #expect(model.isShowingActionsMenu == false)
        #expect(model.store.items.map(\.title) == ["b"])
        #expect(model.selectedItem?.title == "b")
    }

    /// 高亮停在两头不越界。
    @Test func menuHighlightStopsAtTheEnds() throws {
        let model = makePanelModel(copying: ["a"])
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try Self.key("k", .command)))
        for _ in 0..<8 { #expect(controller.handleKeyDown(try Self.key("\u{F700}"))) }
        #expect(model.highlightedActionsMenuEntry == .pasteToTarget)

        for _ in 0..<8 { #expect(controller.handleKeyDown(try Self.key("\u{F701}"))) }
        #expect(model.highlightedActionsMenuEntry == .deleteAll)
    }

    /// ↩ 执行的是高亮项：高亮到「以纯文本粘贴」时执行它，而不是默认的原样粘贴。
    @Test func returnRunsTheHighlightedEntry() throws {
        let model = makePanelModel(copying: ["a"])
        let helper = PasteRecorder()
        model.onPaste = { item, mode in helper.calls.append((item.title, mode)) }
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try Self.key("k", .command)))
        #expect(controller.handleKeyDown(try Self.key("\u{F701}")))
        #expect(controller.handleKeyDown(try Self.key("\u{F701}")))
        #expect(model.highlightedActionsMenuEntry == .pasteAsPlainText)

        #expect(controller.handleKeyDown(try Self.key("\r")))
        #expect(helper.calls.map(\.1) == [.plainText])
        #expect(model.isShowingActionsMenu == false)
    }

    /// 菜单打开时面板快捷键全部屏蔽：⌃X 不删条目、⌘1 不粘贴、字母不进入搜索。
    @Test func panelShortcutsAreBlockedWhileTheMenuIsOpen() throws {
        let model = makePanelModel(copying: ["c", "b", "a"])
        let helper = PasteRecorder()
        model.onPaste = { item, mode in helper.calls.append((item.title, mode)) }
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try Self.key("k", .command)))
        let count = model.store.items.count

        // 这些键被吃掉，但什么都不做。
        #expect(controller.handleKeyDown(try Self.key("x", .control)))
        #expect(controller.handleKeyDown(try Self.key("x", [.control, .shift])))
        #expect(controller.handleKeyDown(try Self.key("2", .command)))
        #expect(controller.handleKeyDown(try Self.key("\r", .option)))
        #expect(controller.handleKeyDown(try Self.key("\u{7F}", .command)))
        #expect(controller.handleKeyDown(try Self.key("a")))
        #expect(controller.handleKeyDown(try Self.key("\u{F703}")))

        #expect(model.store.items.count == count)
        #expect(helper.calls.isEmpty)
        #expect(model.query.isEmpty)
        #expect(model.isPeeking == false)
        // 菜单仍开着，高亮也没动。
        #expect(model.isShowingActionsMenu)
        #expect(model.highlightedActionsMenuEntry == .pasteToTarget)
    }

    /// 鼠标悬停到某一项上，高亮跟过去，↩ 就执行它。
    @Test func hoveringMovesTheHighlight() throws {
        let model = makePanelModel(copying: ["a"])
        model.setRowFrame(CGRect(x: 24, y: 88, width: 392, height: 52), for: try #require(model.selectedItem).id)
        model.perform(.toggleActionsMenu)

        model.highlightActionsMenuEntry(.deleteAll)
        #expect(model.highlightedActionsMenuEntry == .deleteAll)

        model.perform(.toggleActionsMenu)
        model.perform(.toggleActionsMenu)
        #expect(model.highlightedActionsMenuEntry == .pasteToTarget)
    }

    /// 组合键拆成多个键帽：修饰键不与字母同框。
    @Test func combinedShortcutsSplitIntoSeparateKeyCaps() {
        #expect(ClipboardActionsMenuEntry.pasteKeepingPanelOpen.keyCaps == ["⌥", "↩"])
        #expect(ClipboardActionsMenuEntry.pasteAsPlainText.keyCaps == ["⇧", "↩"])
        #expect(ClipboardActionsMenuEntry.deleteEntry.keyCaps == ["⌃", "X"])
        #expect(ClipboardActionsMenuEntry.deleteAll.keyCaps == ["⌃", "⇧", "X"])
        #expect(ClipboardActionsMenuEntry.menuHintKeyCaps == ["⌘", "K"])
        #expect(Self.entries.allSatisfy { $0.keyCaps.allSatisfy { $0.count == 1 } })
    }

    // MARK: 辅助

    private static func key(_ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 0
        ))
    }

    /// 把键帽文字拆回字符与修饰键，例如 `⌃⇧X` → ("x", [.control, .shift])。
    private static func parse(_ shortcut: String) -> (String, EventModifiers) {
        var modifiers: EventModifiers = []
        var characters = ""
        for character in shortcut {
            switch character {
            case "⌘": modifiers.insert(.command)
            case "⌥": modifiers.insert(.option)
            case "⇧": modifiers.insert(.shift)
            case "⌃": modifiers.insert(.control)
            case "↩": characters = "\r"
            default: characters = String(character).lowercased()
            }
        }
        return (characters, modifiers)
    }

    private static func title(_ entry: ClipboardActionsMenuEntry, _ appName: String?, _ identifier: String) -> String {
        guard case .localized(let resource) = entry.title(targetAppName: appName) else { return "" }
        return localized(resource, identifier)
    }

    private static func localized(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: identifier)
        return String(localized: resource)
    }
}

/// 记录粘贴回调，避免在测试里直接写 SwiftData 状态。
@MainActor
final class PasteRecorder {
    var calls: [(String, PasteMode)] = []
}
