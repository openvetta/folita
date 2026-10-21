import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardHistoryScrollTests {
    private let viewport: CGFloat = 400
    private let offset0: CGFloat = 0

    /// 行高与渐隐安全区都取自设计常量，用例直接算期望值，不复制魔法数。
    private var rowPitch: CGFloat {
        ClipboardPanelMetrics.historyRowHeight + ClipboardPanelMetrics.historyRowSpacing
    }

    private var safeBottomLine: CGFloat {
        viewport - ClipboardPanelMetrics.listBottomSafeSpace
    }

    @Test func firstScreenfulNeedsNoScroll() {
        for index in 0..<3 {
            #expect(ClipboardHistoryScroll.targetOffset(
                selectedIndex: index,
                itemCount: 20,
                viewportHeight: viewport,
                currentOffset: offset0
            ) == 0)
        }
    }

    /// 选中行落到渐隐区时，列表上推，行底边正好停在安全线上。
    @Test func selectionInsideFadePushesListUp() {
        let index = 6
        let target = ClipboardHistoryScroll.targetOffset(
            selectedIndex: index,
            itemCount: 20,
            viewportHeight: viewport,
            currentOffset: offset0
        )

        let rowBottom = CGFloat(index) * rowPitch + ClipboardPanelMetrics.historyRowHeight
        #expect(target > 0)
        #expect(target == rowBottom - safeBottomLine)
    }

    /// 已经可见的行不再触发滚动：在列表中部上下切换时不会来回拽动。
    /// 偏移 120 时视口内整行可见的是第 3–5 行（第 2 行顶边 112 已滚出顶部）。
    @Test func visibleSelectionKeepsCurrentOffset() {
        let current: CGFloat = 120
        for index in 3...5 {
            #expect(ClipboardHistoryScroll.targetOffset(
                selectedIndex: index,
                itemCount: 20,
                viewportHeight: viewport,
                currentOffset: current
            ) == current)
        }
    }

    /// 往上选中已被滚出顶部的内容时，列表跟着回到该行。
    @Test func selectionAboveViewportScrollsBack() {
        let index = 2
        let target = ClipboardHistoryScroll.targetOffset(
            selectedIndex: index,
            itemCount: 20,
            viewportHeight: viewport,
            currentOffset: 400
        )

        #expect(target == CGFloat(index) * rowPitch)
    }

    /// 最后一条也能整行抬到安全线上：底部留白本身占用内容高度。
    @Test func lastItemRestsOnSafeLine() {
        let count = 20
        let index = count - 1
        let target = ClipboardHistoryScroll.targetOffset(
            selectedIndex: index,
            itemCount: count,
            viewportHeight: viewport,
            currentOffset: 0
        )

        let contentHeight = CGFloat(count) * ClipboardPanelMetrics.historyRowHeight
            + CGFloat(count - 1) * ClipboardPanelMetrics.historyRowSpacing
            + ClipboardPanelMetrics.listBottomSafeSpace
        #expect(target == contentHeight - viewport)
        #expect(target + safeBottomLine == CGFloat(index) * rowPitch + ClipboardPanelMetrics.historyRowHeight)
    }

    /// 未布局或不存在的行不应把列表拉到别处。
    @Test func invalidInputKeepsOffset() {
        #expect(ClipboardHistoryScroll.targetOffset(selectedIndex: 0, itemCount: 0, viewportHeight: viewport, currentOffset: 40) == 40)
        #expect(ClipboardHistoryScroll.targetOffset(selectedIndex: 0, itemCount: 5, viewportHeight: 0, currentOffset: 40) == 40)
        #expect(ClipboardHistoryScroll.targetOffset(selectedIndex: 9, itemCount: 5, viewportHeight: viewport, currentOffset: 40) == 40)
    }

    /// 底部安全空间与容器渐隐区的起点对齐，设计改动后这里会先失败。
    @Test func bottomSafeSpaceCoversTheFade() {
        let fadeHeight = ClipboardPanelMetrics.containerSize.height * (1 - SiriGlassStyle.contentFadeStart)

        // 560 × 0.3 在浮点下是 168.00000000000003，按容差比较。
        #expect(abs(ClipboardPanelMetrics.listBottomSafeSpace - fadeHeight) < 0.001)
        #expect(ClipboardPanelMetrics.listBottomSafeSpace > 0)
    }
}
