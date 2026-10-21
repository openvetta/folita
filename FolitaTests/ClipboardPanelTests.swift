import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardPanelTests {
    @Test func panelMovesByItsDraggableHeader() {
        let panel = ClipboardPanel()
        panel.setFrame(CGRect(x: 200, y: 600, width: 496, height: 616), display: false)

        // 无边框窗口没有标题栏，若关闭 background drag 则面板完全不可移动。
        #expect(panel.isMovableByWindowBackground)
        #expect(panel.isMovable)
        panel.setFrameOrigin(CGPoint(x: 240, y: 560))
        #expect(panel.frame.origin == CGPoint(x: 240, y: 560))
    }

    @Test func panelIsTransparentNonActivatingAndKeyable() {
        let panel = ClipboardPanel()

        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
        #expect(panel.isFloatingPanel)
        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain == false)
    }

    @Test func windowFrameIsTopCenteredInVisibleArea() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let frame = ClipboardPanelMetrics.windowFrame(in: visible)
        let inset = ClipboardPanelMetrics.shadowInset

        #expect(frame.size == ClipboardPanelMetrics.windowSize)
        #expect(abs(frame.midX - visible.midX) <= 1)
        // 容器（去掉阴影边距）顶边与菜单栏下沿保持固定间距。
        #expect(frame.maxY - inset == visible.maxY - ClipboardPanelMetrics.topSpacing)
    }

    /// 常见流程：设置里改了呼出位置 → 再次呼出落在新位置 → 光标贴边时展开预览仍在屏幕内。
    @Test func showFollowsPlacementSetting() throws {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let pointer = PanelPointer(location: CGPoint(x: 1480, y: 300), visibleFrame: visible)
        let settings = makePlacementSettings(.center)
        let controller = ClipboardPanelController(
            model: makePanelModel(copying: ["a", "b"]),
            placementSettings: settings,
            pointerProvider: { pointer }
        )
        defer { controller.hide() }

        controller.show()
        let panel = try #require(controller.panel)
        #expect(panel.frame == ClipboardPanelMetrics.windowFrame(placement: .center, in: visible, cursor: pointer.location))
        controller.hide()

        settings.placement = .cursor
        controller.show()
        let container = panel.frame.insetBy(dx: ClipboardPanelMetrics.shadowInset, dy: ClipboardPanelMetrics.shadowInset)
        #expect(container.contains(pointer.location))
        // 光标靠近右缘：整体向左挪，容器不超出屏幕。
        #expect(container.maxX == visible.maxX)

        // 在该位置展开预览（窗口按所在屏幕夹取）：加宽后仍在屏幕内，顶边不动。
        let expanded = ClipboardPanelMetrics.windowFrame(resizing: panel.frame, isPeeking: true, visibleFrame: visible)
        let peeking = expanded.insetBy(dx: ClipboardPanelMetrics.shadowInset, dy: ClipboardPanelMetrics.shadowInset)
        #expect(peeking.maxX <= visible.maxX)
        #expect(peeking.minX >= visible.minX)
        #expect(expanded.maxY == panel.frame.maxY)
    }

    @Test func toggleShowsAndHidesPanel() {
        let controller = ClipboardPanelController(model: makePanelModel(), placementSettings: makePlacementSettings())
        #expect(controller.isVisible == false)

        controller.toggle()
        #expect(controller.isVisible)

        controller.toggle()
        #expect(controller.isVisible == false)
    }

    @Test func escapeHidesPanel() throws {
        let controller = ClipboardPanelController(model: makePanelModel(), placementSettings: makePlacementSettings())
        controller.show()
        let panel = try #require(controller.panel)
        #expect(panel.isVisible)

        panel.cancelOperation(nil)

        #expect(controller.isVisible == false)
        #expect(panel.isVisible == false)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func panelViewLaysOutAtWindowSize(colorScheme: ColorScheme) {
        let view = NSHostingView(rootView: ClipboardPanelView(model: makePanelModel(copying: ["a", "https://folita.app"])).environment(\.colorScheme, colorScheme))
        view.layoutSubtreeIfNeeded()

        #expect(view.fittingSize == ClipboardPanelMetrics.windowSize)
    }

    // MARK: 键盘

    private func key(_ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
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

    /// AppKit 事件到面板命令的映射；字母等普通按键交给搜索框。
    @Test func appKitKeyEventsMapToPanelCommands() throws {
        #expect(ClipboardPanelCommand.command(for: try key("\u{F700}")) == .moveUp)
        #expect(ClipboardPanelCommand.command(for: try key("\u{F701}")) == .moveDown)
        #expect(ClipboardPanelCommand.command(for: try key("\r")) == .paste(.original))
        #expect(ClipboardPanelCommand.command(for: try key("\r", .shift)) == .paste(.plainText))
        #expect(ClipboardPanelCommand.command(for: try key("\u{7F}", .command)) == .deleteSelected)
        #expect(ClipboardPanelCommand.command(for: try key("\u{1B}")) == .dismiss)
        #expect(ClipboardPanelCommand.command(for: try key("3", .command)) == .pasteAt(2))
        #expect(ClipboardPanelCommand.command(for: try key("a")) == nil)
        #expect(ClipboardPanelCommand.command(for: try key("1")) == nil)
    }

    /// 搜索框聚焦时方向键也不能被 TextField 吃掉：面板打开期间上下键切选中项。
    @Test func arrowKeysMoveSelectionWhilePanelIsOpen() throws {
        let model = makePanelModel(copying: ["first", "second", "third"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        let items = model.visibleItems
        #expect(items.count == 3)
        #expect(model.selectedItem?.id == items[0].id)

        #expect(controller.handleKeyDown(try key("\u{F701}")))
        #expect(model.selectedItem?.id == items[1].id)

        #expect(controller.handleKeyDown(try key("\u{F700}")))
        #expect(model.selectedItem?.id == items[0].id)

        // 列表到头后停在原处，不越界。
        #expect(controller.handleKeyDown(try key("\u{F700}")))
        #expect(model.selectedItem?.id == items[0].id)

        // 普通字符不拦截，继续交给搜索框输入。
        #expect(controller.handleKeyDown(try key("a")) == false)
    }

    @Test func commandKeysActOnTheSelectedItem() throws {
        let model = makePanelModel(copying: ["keep", "remove"])
        var pasted: [PasteMode] = []
        model.onPaste = { _, mode in pasted.append(mode) }
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        defer { controller.hide() }

        #expect(controller.handleKeyDown(try key("\r")))
        #expect(pasted == [.original])

        let count = model.store.items.count
        #expect(controller.handleKeyDown(try key("\u{7F}", .command)))
        #expect(model.store.items.count == count - 1)
    }

    /// 输入法组字时方向键用于选词，不能被当成面板快捷键。
    @Test func composingTextKeepsArrowKeys() {
        #expect(ClipboardPanelCommand.isComposing(in: nil) == false)
        #expect(ClipboardPanelCommand.isComposing(in: NSTextView()) == false)

        let editor = NSTextView()
        editor.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(ClipboardPanelCommand.isComposing(in: editor))
    }

    // MARK: 详情预览

    /// 常见流程：→ 加宽并预览 → ↓ 切换条目仍在预览 → ← 退出并缩回原宽度 → Esc 收起面板。
    @Test func peekKeyboardFlowResizesPanel() async throws {
        let model = makePanelModel(copying: ["third", "second", "first"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings(), peekCollapseDelay: .zero)
        controller.show()
        defer { controller.hide() }
        let panel = try #require(controller.panel)
        let narrow = panel.frame
        let items = model.visibleItems

        #expect(controller.handleKeyDown(try key("\u{F703}")))
        #expect(model.isPeeking)
        #expect(panel.frame.size == ClipboardPanelMetrics.windowSize(isPeeking: true))
        // 两侧等量加宽，顶边不动：容器在屏幕上的位置不跳。
        #expect(abs(panel.frame.midX - narrow.midX) <= 1)
        #expect(panel.frame.maxY == narrow.maxY)

        #expect(controller.handleKeyDown(try key("\u{F701}")))
        #expect(model.isPeeking)
        #expect(model.selectedItem?.id == items[1].id)

        #expect(controller.handleKeyDown(try key("\u{F702}")))
        #expect(model.isPeeking == false)
        await controller.peekCollapse?.value
        // 收窄后回到原位，而不是以左边缘为基准缩回。
        #expect(panel.frame == narrow)

        // 预览已收起时 ← 交还给搜索框移动光标。
        #expect(controller.handleKeyDown(try key("\u{F702}")) == false)

        #expect(controller.handleKeyDown(try key("\u{F703}")))
        #expect(controller.handleKeyDown(try key("\u{1B}")))
        #expect(controller.isVisible == false)
        // 收起时就已复位，下次呼出不会再看到从加宽到默认的变形动画。
        #expect(model.isPeeking == false)
        #expect(panel.frame.size == ClipboardPanelMetrics.windowSize)

        // 再次呼出时回到普通宽度。
        controller.show()
        #expect(model.isPeeking == false)
        #expect(panel.frame.size == ClipboardPanelMetrics.windowSize)
    }

    /// 窗口贴近屏幕边缘时，加宽的部分向内挪，不跑出屏幕。
    @Test func peekFrameStaysOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let inset = ClipboardPanelMetrics.shadowInset
        let centered = ClipboardPanelMetrics.windowFrame(in: visible)
        let wide = ClipboardPanelMetrics.windowFrame(resizing: centered, isPeeking: true, visibleFrame: visible)
        #expect(wide.size == ClipboardPanelMetrics.windowSize(isPeeking: true))
        #expect(abs(wide.midX - centered.midX) <= 1)

        let nearRight = centered.offsetBy(dx: visible.maxX - centered.maxX + inset, dy: 0)
        let clamped = ClipboardPanelMetrics.windowFrame(resizing: nearRight, isPeeking: true, visibleFrame: visible)
        #expect(clamped.maxX - inset == visible.maxX)
        #expect(clamped.maxY == nearRight.maxY)
    }

    /// 搜索词中间的光标需要 ← → 移动：只有光标停在末尾时 → 才进入预览。
    @Test func horizontalArrowsRespectTheSearchCaret() {
        let editor = NSTextView()
        editor.string = "query"
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(ClipboardPanelCommand.peek.isIntercepted(isPeeking: false, responder: editor) == false)
        #expect(ClipboardPanelCommand.peek.isIntercepted(isPeeking: true, responder: editor))

        editor.setSelectedRange(NSRange(location: 0, length: 5))
        #expect(ClipboardPanelCommand.peek.isIntercepted(isPeeking: false, responder: editor) == false)

        editor.setSelectedRange(NSRange(location: 5, length: 0))
        #expect(ClipboardPanelCommand.peek.isIntercepted(isPeeking: false, responder: editor))
        #expect(ClipboardPanelCommand.peek.isIntercepted(isPeeking: false, responder: nil))

        #expect(ClipboardPanelCommand.endPeek.isIntercepted(isPeeking: false, responder: editor) == false)
        #expect(ClipboardPanelCommand.endPeek.isIntercepted(isPeeking: true, responder: editor))
        #expect(ClipboardPanelCommand.moveDown.isIntercepted(isPeeking: false, responder: editor))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func panelViewLaysOutWhilePeeking(colorScheme: ColorScheme) {
        let model = makePanelModel(copying: ["a", "https://folita.app"])
        model.perform(.peek)
        #expect(model.isPeeking)

        let view = NSHostingView(rootView: ClipboardPanelView(model: model).environment(\.colorScheme, colorScheme))
        view.layoutSubtreeIfNeeded()

        #expect(view.fittingSize == ClipboardPanelMetrics.windowSize(isPeeking: true))
    }

    /// 面板收起后不再消费按键，避免影响其他窗口。
    @Test func keysAreIgnoredWhilePanelIsHidden() throws {
        let controller = ClipboardPanelController(model: makePanelModel(copying: ["a", "b"]), placementSettings: makePlacementSettings())

        #expect(controller.handleKeyDown(try key("\u{F701}")) == false)
    }
}
