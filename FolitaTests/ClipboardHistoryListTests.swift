import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardHistoryListTests {
    nonisolated private static let appearances: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private func host(_ view: some View, locale: String, scheme: ColorScheme) -> NSHostingView<some View> {
        let host = NSHostingView(
            rootView: view
                .frame(width: 392, height: 400)
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()
        return host
    }

    @Test(arguments: appearances)
    func listWithItemsLaysOut(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: [
            "A long paragraph that should wrap onto a second line and then truncate gracefully in the row",
            "https://folita.app", "#1E90FF", "hello@folita.app",
        ])
        let host = host(ClipboardHistoryList(model: model), locale: locale, scheme: scheme)
        #expect(host.fittingSize == CGSize(width: 392, height: 400))
    }

    /// 详情预览时列表收窄到左侧一列，行仍保持统一高度并完成布局。
    @Test(arguments: appearances)
    func compactListLaysOutWhilePeeking(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: ["https://folita.app", "#1E90FF", "A long paragraph that should truncate"])
        model.perform(.peek)
        #expect(model.isPeeking)

        let width = ClipboardPanelMetrics.listColumnWidth(isPeeking: true)
        let host = NSHostingView(
            rootView: ClipboardHistoryList(model: model)
                .frame(width: width, height: 400)
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == CGSize(width: width, height: 400))
    }

    @Test(arguments: appearances)
    func emptyStatesLayOut(locale: String, scheme: ColorScheme) {
        let empty = makePanelModel()
        #expect(host(ClipboardHistoryList(model: empty), locale: locale, scheme: scheme).fittingSize.height == 400)

        let noMatch = makePanelModel(copying: ["alpha"])
        noMatch.query = "zzz"
        #expect(noMatch.visibleItems.isEmpty)
        #expect(host(ClipboardHistoryList(model: noMatch), locale: locale, scheme: scheme).fittingSize.height == 400)
    }

    @Test(arguments: appearances)
    func emptyViewLaysOutDirectly(locale: String, scheme: ColorScheme) {
        let view = ClipboardHistoryEmptyView(
            symbolName: "list.bullet",
            title: "Nothing here yet",
            message: "Copied text, images and files will appear here."
        )
        let host = NSHostingView(
            rootView: view
                .frame(width: 392, height: 400)
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize == CGSize(width: 392, height: 400))
    }

    @Test(arguments: ClipCategory.allCases)
    func everyCategoryHasDistinctSymbol(category: ClipCategory) {
        let others = ClipCategory.allCases.filter { $0 != category }.map(\.symbolName)
        #expect(!others.contains(category.symbolName))
    }

    @Test func showingPanelResetsSearchAndRefocuses() {
        let model = makePanelModel(copying: ["a"])
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        model.query = "leftover"
        let count = model.presentationCount

        controller.show()
        defer { controller.hide() }

        #expect(model.query.isEmpty)
        #expect(model.presentationCount == count + 1)
    }

    @Test func escapeFromModelHidesPanel() {
        let model = makePanelModel()
        let controller = ClipboardPanelController(model: model, placementSettings: makePlacementSettings())
        controller.show()
        model.perform(.dismiss)
        #expect(!controller.isVisible)
    }

    /// 列表把每一行的位置写回模型（容器坐标系）：菜单定位与右键命中都靠它。
    @Test(arguments: [ColorScheme.dark, .light])
    func listReportsRowFramesInPanelCoordinates(scheme: ColorScheme) async {
        let model = makePanelModel(copying: ["c", "b", "a"])
        let view = NSHostingView(rootView: ClipboardPanelView(model: model).environment(\.colorScheme, scheme))
        view.frame = CGRect(origin: .zero, size: ClipboardPanelMetrics.windowSize)
        view.layoutSubtreeIfNeeded()
        // 几何回调在布局事务结束后才到齐。
        for _ in 0..<5 where model.rowFrames.count < 3 {
            await Task.yield()
            view.layoutSubtreeIfNeeded()
        }

        let items = model.visibleItems
        #expect(items.count == 3)
        let frames = try? items.map { item in
            try #require(model.rowFrames[item.id])
        }
        let rows = frames ?? []
        #expect(rows.count == 3)
        guard rows.count == 3 else { return }

        // 行在容器内左侧内边距处，自上而下按同一行高排列。
        #expect(rows.allSatisfy { $0.minX == ClipboardPanelMetrics.contentInset })
        #expect(rows.allSatisfy { $0.height == ClipboardPanelMetrics.historyRowHeight })
        #expect(rows[0].minY < rows[1].minY && rows[1].minY < rows[2].minY)
        #expect(rows.allSatisfy { $0.maxY <= ClipboardPanelMetrics.containerSize.height })

        // 用右键命中验证这份几何确实可用。
        model.setRowFrame(rows[1], for: items[1].id)
        #expect(model.item(at: CGPoint(x: rows[1].midX, y: rows[1].midY))?.id == items[1].id)
    }
}
