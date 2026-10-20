import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct PanelNoticeTests {
    @Test(arguments: [
        (true, false, NSPasteboard.AccessBehavior.alwaysAllow, PanelNotice.accessibilityNeeded),
        (true, true, .alwaysAllow, .none),
        (false, false, .alwaysAllow, .none),
        (true, true, .alwaysDeny, .pasteboardDenied),
        (true, false, .alwaysDeny, .pasteboardDenied),
        (true, true, .ask, .none),
        (true, true, .default, .none),
    ])
    func resolvesHighestPriorityNotice(
        autoPaste: Bool,
        trusted: Bool,
        behavior: NSPasteboard.AccessBehavior,
        expected: PanelNotice
    ) {
        #expect(PanelNotice.resolve(autoPaste: autoPaste, accessibilityTrusted: trusted, pasteboardBehavior: behavior) == expected)
    }

    @Test func noticesLinkToSystemSettings() {
        #expect(PanelNotice.none.settingsURL == nil)
        #expect(PanelNotice.accessibilityNeeded.settingsURL?.absoluteString.hasSuffix("Privacy_Accessibility") == true)
        #expect(PanelNotice.pasteboardDenied.settingsURL?.scheme == "x-apple.systempreferences")
    }

    @Test func noticeRefreshesOnPresentationAndResolvesThroughModel() {
        let model = makePanelModel()
        var current = PanelNotice.accessibilityNeeded
        var resolved: [PanelNotice] = []
        model.noticeProvider = { current }
        model.onResolveNotice = { resolved.append($0) }

        model.prepareForPresentation()
        #expect(model.notice == .accessibilityNeeded)
        model.resolveNotice()

        current = .none
        model.prepareForPresentation()
        #expect(model.notice == .none)
        #expect(resolved == [.accessibilityNeeded])
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func bannerLaysOutForEveryNotice(locale: String, scheme: ColorScheme) {
        for notice in [PanelNotice.accessibilityNeeded, .pasteboardDenied] {
            let host = NSHostingView(
                rootView: PanelNoticeBanner(notice: notice, action: {})
                    .frame(width: 392)
                    .environment(\.locale, Locale(identifier: locale))
                    .environment(\.colorScheme, scheme)
            )
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.width == 392)
            #expect(host.fittingSize.height > 40)
        }

        let none = NSHostingView(rootView: PanelNoticeBanner(notice: .none, action: {}))
        none.layoutSubtreeIfNeeded()
        #expect(none.fittingSize.height == 0)
    }
}
