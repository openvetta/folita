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

    @Test(arguments: appearances)
    func emptyStatesLayOut(locale: String, scheme: ColorScheme) {
        let empty = makePanelModel()
        #expect(host(ClipboardHistoryList(model: empty), locale: locale, scheme: scheme).fittingSize.height == 400)

        let noMatch = makePanelModel(copying: ["alpha"])
        noMatch.query = "zzz"
        #expect(noMatch.visibleItems.isEmpty)
        #expect(host(ClipboardHistoryList(model: noMatch), locale: locale, scheme: scheme).fittingSize.height == 400)
    }

    @Test(arguments: ClipCategory.allCases)
    func everyCategoryHasDistinctSymbol(category: ClipCategory) {
        let others = ClipCategory.allCases.filter { $0 != category }.map(\.symbolName)
        #expect(!others.contains(category.symbolName))
    }

    @Test func showingPanelResetsSearchAndRefocuses() {
        let model = makePanelModel(copying: ["a"])
        let controller = ClipboardPanelController(model: model)
        model.query = "leftover"
        let count = model.presentationCount

        controller.show()
        defer { controller.hide() }

        #expect(model.query.isEmpty)
        #expect(model.presentationCount == count + 1)
    }

    @Test func escapeFromModelHidesPanel() {
        let model = makePanelModel()
        let controller = ClipboardPanelController(model: model)
        controller.show()
        model.perform(.dismiss)
        #expect(!controller.isVisible)
    }
}
