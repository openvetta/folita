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
}
