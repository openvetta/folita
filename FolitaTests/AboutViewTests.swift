import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct AboutViewTests {
    @Test func linksPointToRepository() {
        #expect(AppInfo.repositoryURL.absoluteString == "https://github.com/openvetta/folita")
        #expect(AppInfo.licenseURL.absoluteString.hasPrefix(AppInfo.repositoryURL.absoluteString))
        #expect(AppInfo.version != "?" && !AppInfo.version.isEmpty)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func laysOut(locale: String, scheme: ColorScheme) {
        let host = NSHostingView(rootView: AboutView()
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme))
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 420)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)
    }

    @Test(arguments: MainSection.allCases)
    func everySectionHasAPage(section: MainSection) {
        let services = TestServices()
        // 快捷键页的录制控件会写入真实 UserDefaults，此处只验证路由，不渲染其内容。
        guard section != .shortcuts else { return }
        let host = NSHostingView(rootView: MainPanelView(initialSection: section).testServices(services, locale: "en"))
        host.frame = CGRect(x: 0, y: 0, width: 760, height: 520)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 760)
    }
}
