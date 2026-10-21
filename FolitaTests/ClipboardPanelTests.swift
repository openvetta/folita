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

    @Test func toggleShowsAndHidesPanel() {
        let controller = ClipboardPanelController(model: makePanelModel())
        #expect(controller.isVisible == false)

        controller.toggle()
        #expect(controller.isVisible)

        controller.toggle()
        #expect(controller.isVisible == false)
    }

    @Test func escapeHidesPanel() throws {
        let controller = ClipboardPanelController(model: makePanelModel())
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
        let controller = ClipboardPanelController(model: model)
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
        let controller = ClipboardPanelController(model: model)
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

    /// 面板收起后不再消费按键，避免影响其他窗口。
    @Test func keysAreIgnoredWhilePanelIsHidden() throws {
        let controller = ClipboardPanelController(model: makePanelModel(copying: ["a", "b"]))

        #expect(controller.handleKeyDown(try key("\u{F701}")) == false)
    }
}
