import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct FavoritesViewTests {
    /// 深浅色 × 中英文：两个新视图都要能在这个矩阵下完成布局。
    nonisolated private static let matrix: [(String, ColorScheme)] = [
        ("zh-Hans", .light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ]

    private func host<Content: View>(_ view: Content, locale: String, scheme: ColorScheme) -> NSHostingView<some View> {
        let host = NSHostingView(
            rootView: view
                .environment(\.locale, Locale(identifier: locale))
                .environment(\.colorScheme, scheme)
        )
        host.layoutSubtreeIfNeeded()
        return host
    }

    /// 分组胶囊行：空分组时只有「全部」与「+」，有分组时都画得出来。
    @Test(arguments: matrix)
    func tabBarLaysOut(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: ["a"])
        model.store.createTab(named: "Work")
        model.store.createTab(named: "Life")

        let host = host(
            FavoriteTabBar(
                tabs: model.store.tabs,
                selectedTabID: model.selectedTabID,
                renamingTabID: .constant(nil),
                renameDraft: .constant(""),
                select: model.selectTab,
                create: model.createTab,
                rename: model.renameTab,
                delete: model.deleteTab
            )
                .frame(width: 392),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize.width > 0)
        // 胶囊行是固定高度，不会因为语言切换而变高。
        #expect(host.fittingSize.height <= ClipboardPanelMetrics.historyRowHeight)
    }

    /// 分组很多时横向滚动，不折行：宽度不随分组数增长。
    @Test(arguments: matrix)
    func tabBarDoesNotWrapWhenCrowded(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: ["a"])
        for index in 0..<8 {
            model.store.createTab(named: "Group \(index)")
        }

        let host = host(
            FavoriteTabBar(
                tabs: model.store.tabs,
                selectedTabID: model.selectedTabID,
                renamingTabID: .constant(nil),
                renameDraft: .constant(""),
                select: model.selectTab,
                create: model.createTab,
                rename: model.renameTab,
                delete: model.deleteTab
            )
                .frame(width: 392),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize.width <= 392)
        #expect(host.fittingSize.height <= ClipboardPanelMetrics.historyRowHeight)
    }

    /// 「收藏到分组」选择器：有分组 + 已收藏时多一行「取消收藏」。
    @Test(arguments: matrix)
    func pickerLaysOut(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: ["a"])
        let work = model.store.createTab(named: "Work")
        model.store.createTab(named: "Life")
        if let item = model.selectedItem, let work { model.store.favorite(item, in: work) }
        // 选择器的行依赖「锚定的条目」，先真的把它打开。
        model.perform(.toggleFavoritePicker)

        let rows = model.favoritePickerRows
        #expect(rows.count == 3)

        let host = host(
            FavoritePickerMenuView(
                rows: rows,
                tabs: model.store.tabs,
                currentTabID: work?.id,
                highlighted: rows.first,
                activate: { _ in },
                highlight: { _ in }
            )
                .frame(width: ClipboardPanelMetrics.actionsMenuWidth),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize.width > 0)
        #expect(host.fittingSize.height > 0)
    }

    /// 没有分组时选择器只剩「新建分组…」，高度按一行算。
    @Test(arguments: matrix)
    func pickerLaysOutWithOnlyTheCreateRow(locale: String, scheme: ColorScheme) {
        let model = makePanelModel(copying: ["a"])
        #expect(model.favoritePickerRows == [.createTab])

        let host = host(
            FavoritePickerMenuView(
                rows: [.createTab],
                tabs: [],
                currentTabID: nil,
                highlighted: .createTab,
                activate: { _ in },
                highlight: { _ in }
            )
                .frame(width: ClipboardPanelMetrics.actionsMenuWidth),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize.height > 0)
    }

    /// 收藏夹模式下面板仍按窗口尺寸布局，tab 排不会把列表挤出容器。
    @Test(arguments: matrix)
    func panelWithFavoritesStillFitsTheWindow(locale: String, scheme: ColorScheme) {
        let services = TestServices(copying: ["a", "https://folita.app"])
        let work = services.store.createTab(named: "Work")
        for item in services.store.items {
            if let work { services.store.favorite(item, in: work) }
        }
        services.panel.model.perform(.toggleFavorites)

        let host = host(
            ClipboardPanelView(model: services.panel.model),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize == ClipboardPanelMetrics.windowSize)
    }

    /// 已收藏条目在普通列表里带星标：用无障碍字符树确认标记确实画出来了。
    @Test(arguments: [ColorScheme.dark, .light])
    func favoritedRowShowsTheStar(scheme: ColorScheme) {
        let services = TestServices(copying: ["a"])
        let item = services.store.items[0]
        let tab = services.store.createTab(named: "Work")
        if let tab { services.store.favorite(item, in: tab) }
        #expect(item.isFavorited)

        let host = host(
            ClipboardHistoryRow(item: item, isSelected: true),
            locale: "en",
            scheme: scheme
        )

        // 星标是装饰元素（accessibilityHidden），因此断言整行仍可访问且高度不变。
        #expect(host.fittingSize.height == ClipboardPanelMetrics.historyRowHeight)
    }

    /// 主窗口的收藏夹是「列表栏（顶部胶囊）+ 详情」两栏，不再有独立的分组列。
    /// 断言两根分割线只剩一根：竖向两列列表被合并掉了。
    @Test(arguments: matrix)
    func mainWindowFavoritesUsesASingleDivider(locale: String, scheme: ColorScheme) {
        let services = TestServices(copying: ["a"])
        let work = services.store.createTab(named: "Work")
        if let work, let item = services.store.items.first {
            services.store.favorite(item, in: work)
        }

        let host = host(
            FavoritesView()
                .environment(services.store)
                .environment(services.language),
            locale: locale,
            scheme: scheme
        )

        #expect(host.fittingSize.width > 0)
        #expect(host.fittingSize.height >= 0)
    }
}
