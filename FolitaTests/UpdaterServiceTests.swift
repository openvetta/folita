import AppKit
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct UpdaterServiceTests {
    @Test(arguments: [
        (nil as String?, false), ("", false), ("  ", false), ("$(SPARKLE_PUBLIC_ED_KEY)", false),
        ("pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=", true),
    ])
    func configuredOnlyWithRealPublicKey(key: String?, expected: Bool) {
        #expect(UpdaterService.isConfigured(publicKey: key) == expected)
    }

    @Test func unconfiguredBuildDoesNothing() {
        let updater = UpdaterService(backend: nil)
        #expect(!updater.isConfigured)
        updater.automaticallyChecks = true
        updater.checkForUpdates()
    }

    @Test func forwardsPreferenceAndManualCheck() {
        var automatic = true
        var checks = 0
        let updater = UpdaterService(backend: .init(
            automaticallyChecks: { automatic },
            setAutomaticallyChecks: { automatic = $0 },
            checkForUpdates: { checks += 1 }
        ))
        #expect(updater.isConfigured)
        #expect(updater.automaticallyChecks)

        updater.automaticallyChecks = false
        updater.checkForUpdates()
        #expect(automatic == false)
        #expect(checks == 1)
    }

    /// 本仓库的测试构建未配置公钥，Sparkle 不应被启动。
    @Test func testHostBuildIsNotConfigured() {
        #expect(!UpdaterService.isConfigured(publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String))
        #expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
            == AppInfo.repositoryURL.absoluteString + "/releases/latest/download/appcast.xml")
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light, false), ("zh-Hans", .dark, true),
        ("en", .light, true), ("en", .dark, false),
    ])
    func generalSettingsLaysOutWithUpdates(locale: String, scheme: ColorScheme, configured: Bool) {
        let services = TestServices()
        if configured {
            services.updater = UpdaterService(backend: .init(
                automaticallyChecks: { true }, setAutomaticallyChecks: { _ in }, checkForUpdates: {}
            ))
        }
        let host = NSHostingView(rootView: GeneralSettingsView().testServices(services, locale: locale, scheme: scheme))
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 760)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.width == 520)
    }
}
