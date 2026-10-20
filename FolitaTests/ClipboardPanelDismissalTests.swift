import CoreGraphics
import Testing
@testable import Folita

struct ClipboardPanelDismissalTests {
    private let panel = CGRect(x: 100, y: 500, width: 496, height: 616)

    @Test func clickInsidePanelKeepsItOpen() {
        #expect(!ClipboardPanelDismissal.shouldDismiss(clickAt: CGPoint(x: 300, y: 700), panelFrame: panel, attachedFrames: []))
    }

    @Test func clickOutsidePanelDismisses() {
        #expect(ClipboardPanelDismissal.shouldDismiss(clickAt: CGPoint(x: 900, y: 300), panelFrame: panel, attachedFrames: []))
        #expect(ClipboardPanelDismissal.shouldDismiss(clickAt: CGPoint(x: 20, y: 20), panelFrame: panel, attachedFrames: []))
    }

    @Test func clickOnPanelEdgeCountsAsInside() {
        #expect(!ClipboardPanelDismissal.shouldDismiss(clickAt: panel.origin, panelFrame: panel, attachedFrames: []))
        #expect(!ClipboardPanelDismissal.shouldDismiss(
            clickAt: CGPoint(x: panel.maxX - 1, y: panel.maxY - 1),
            panelFrame: panel,
            attachedFrames: []
        ))
        // 边框外沿再往外一点就算面板外。
        #expect(ClipboardPanelDismissal.shouldDismiss(
            clickAt: CGPoint(x: panel.maxX + 1, y: panel.maxY + 1),
            panelFrame: panel,
            attachedFrames: []
        ))
    }

    @Test func clickOnAttachedPopoverKeepsPanelOpen() {
        // 筛选气泡浮在面板右侧之外，点它不能把面板一起收掉。
        let popover = CGRect(x: 600, y: 760, width: 244, height: 320)
        #expect(!ClipboardPanelDismissal.shouldDismiss(clickAt: CGPoint(x: 700, y: 800), panelFrame: panel, attachedFrames: [popover]))
        #expect(ClipboardPanelDismissal.shouldDismiss(clickAt: CGPoint(x: 700, y: 400), panelFrame: panel, attachedFrames: [popover]))
    }
}
