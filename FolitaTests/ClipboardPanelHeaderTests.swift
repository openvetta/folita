import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardPanelHeaderTests {
    @Test func filterCasesMatchExpectedOptions() {
        #expect(ClipboardFilter.allCases == [.all, .text, .images, .files, .links, .colors, .emails])
    }

    /// `textformat` 在中文环境下会渲染成「格式」二字而不是图标。
    @Test func symbolsAreNotLocalizedGlyphs() {
        let symbols = ClipboardFilter.allCases.map(\.symbolName) + ClipCategory.allCases.map(\.symbolName)
        #expect(!symbols.contains { $0.hasPrefix("textformat") })
    }

    @Test func filterSymbolsAreDistinct() {
        let symbols = ClipboardFilter.allCases.map(\.symbolName)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light),
        ("zh-Hans", ColorScheme.dark),
        ("en", ColorScheme.light),
        ("en", ColorScheme.dark),
    ])
    func filterMenuLaysOut(localeIdentifier: String, colorScheme: ColorScheme) {
        let host = NSHostingView(
            rootView: ClipboardFilterMenu(model: makePanelModel(copying: ["a"]))
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .environment(\.colorScheme, colorScheme)
        )
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.width > 0)
        #expect(host.fittingSize.height > 0)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light),
        ("zh-Hans", ColorScheme.dark),
        ("en", ColorScheme.light),
        ("en", ColorScheme.dark),
    ])
    func searchFieldFillsAvailableWidth(localeIdentifier: String, colorScheme: ColorScheme) {
        struct Host: View {
            @State var query = "folita"
            @FocusState var focused: Bool
            var body: some View {
                ClipboardSearchField(query: $query, isFocused: $focused).frame(width: 300)
            }
        }
        let host = NSHostingView(
            rootView: Host()
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .environment(\.colorScheme, colorScheme)
        )
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize == CGSize(width: 300, height: ClipboardPanelMetrics.controlHeight))
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func panelViewStillLaysOutAtWindowSize(colorScheme: ColorScheme) {
        let view = NSHostingView(rootView: ClipboardPanelView(model: makePanelModel(copying: ["a", "https://folita.app"])).environment(\.colorScheme, colorScheme))
        view.layoutSubtreeIfNeeded()

        #expect(view.fittingSize == ClipboardPanelMetrics.windowSize)
    }
}
