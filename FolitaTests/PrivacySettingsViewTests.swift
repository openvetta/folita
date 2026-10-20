import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct PrivacySettingsViewTests {
    @Test func readsBundleIDFromChosenApp() throws {
        let app = FileManager.default.temporaryDirectory.appending(path: "FolitaTests-\(UUID().uuidString)/Bank.app")
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "com.example.bank", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))

        #expect(PrivacySettingsView.bundleID(ofAppAt: app) == "com.example.bank")
        #expect(PrivacySettingsView.bundleID(ofAppAt: app.deletingLastPathComponent()) == nil)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light), ("zh-Hans", .dark), ("en", .light), ("en", .dark),
    ])
    func laysOutEmptyAndWithIgnoredApps(locale: String, scheme: ColorScheme) {
        let services = TestServices()
        let host = NSHostingView(rootView: PrivacySettingsView().testServices(services, locale: locale, scheme: scheme))
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 520)
        host.layoutSubtreeIfNeeded()

        // 已安装与已卸载（只剩 bundle ID）的应用都能显示。
        services.privacy.ignore(bundleID: "com.apple.finder")
        services.privacy.ignore(bundleID: "com.example.uninstalled")
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)
        #expect(services.privacy.ignoredBundleIDs.count == 2)
    }
}
