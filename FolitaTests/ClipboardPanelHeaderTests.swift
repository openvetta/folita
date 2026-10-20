import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct ClipboardPanelHeaderTests {
    @Test func filterCasesMatchExpectedOptions() {
        #expect(ClipboardFilter.allCases == [.all, .text, .images, .files, .links, .colors, .emails])
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
            rootView: ClipboardFilterMenu(selection: .constant(.text))
                .environment(\.locale, Locale(identifier: localeIdentifier))
                .environment(\.colorScheme, colorScheme)
        )
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.width > 0)
        #expect(host.fittingSize.height > 0)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func panelViewStillLaysOutAtWindowSize(colorScheme: ColorScheme) {
        let view = NSHostingView(rootView: ClipboardPanelView().environment(\.colorScheme, colorScheme))
        view.layoutSubtreeIfNeeded()

        #expect(view.fittingSize == ClipboardPanelMetrics.windowSize)
    }
}
