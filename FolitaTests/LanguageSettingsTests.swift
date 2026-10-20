import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Folita

@MainActor
struct LanguageSettingsTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "app.folita.tests.languagesettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func systemLanguageResolution() {
        #expect(LanguageSettings.resolveSystemLanguage(preferredLanguages: ["zh-Hans-CN", "en-US"]) == .simplifiedChinese)
        #expect(LanguageSettings.resolveSystemLanguage(preferredLanguages: ["zh-Hant-TW", "en"]) == .simplifiedChinese)
        #expect(LanguageSettings.resolveSystemLanguage(preferredLanguages: ["zh-HK"]) == .simplifiedChinese)
        #expect(LanguageSettings.resolveSystemLanguage(preferredLanguages: ["en-US", "zh-Hans"]) == .english)
        #expect(LanguageSettings.resolveSystemLanguage(preferredLanguages: ["ja-JP", "fr-FR"]) == .english)
    }

    @Test func defaultsToSystemAndFollowsPreferredLanguages() {
        let defaults = makeIsolatedDefaults()
        let settings = LanguageSettings(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["zh-Hans-CN", "en"] }
        )

        #expect(settings.selectedLanguage == .system)
        #expect(settings.effectiveLanguage == .simplifiedChinese)
        #expect(settings.effectiveLocale.identifier == "zh-Hans")
    }

    @Test func userCanSwitchBetweenEnglishAndChinese() {
        let defaults = makeIsolatedDefaults()
        let settings = LanguageSettings(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        // 切换为英文
        settings.selectedLanguage = .english
        #expect(settings.selectedLanguage == .english)
        #expect(settings.effectiveLanguage == .english)
        #expect(settings.effectiveLocale.identifier == "en")
        #expect(defaults.string(forKey: LanguageSettings.userDefaultsKey) == "en")

        // 切换为中文
        settings.selectedLanguage = .simplifiedChinese
        #expect(settings.selectedLanguage == .simplifiedChinese)
        #expect(settings.effectiveLanguage == .simplifiedChinese)
        #expect(settings.effectiveLocale.identifier == "zh-Hans")
        #expect(defaults.string(forKey: LanguageSettings.userDefaultsKey) == "zh-Hans")

        // 切回跟随系统
        settings.selectedLanguage = .system
        #expect(settings.selectedLanguage == .system)
        #expect(settings.effectiveLanguage == .simplifiedChinese)
        #expect(defaults.string(forKey: LanguageSettings.userDefaultsKey) == "system")
    }

    @Test func restoresSavedSelectionFromUserDefaults() {
        let defaults = makeIsolatedDefaults()
        defaults.set(AppLanguage.english.rawValue, forKey: LanguageSettings.userDefaultsKey)

        let settings = LanguageSettings(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )
        #expect(settings.selectedLanguage == .english)
        #expect(settings.effectiveLanguage == .english)
    }

    @Test(arguments: [
        ("zh-Hans", ColorScheme.light),
        ("zh-Hans", ColorScheme.dark),
        ("en", ColorScheme.light),
        ("en", ColorScheme.dark),
    ])
    func generalSettingsViewLaysOut(localeIdentifier: String, colorScheme: ColorScheme) {
        let services = TestServices()
        let host = NSHostingView(rootView: GeneralSettingsView().testServices(services, locale: localeIdentifier, scheme: colorScheme))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width >= 0)
        #expect(host.fittingSize.height >= 0)
    }

    @Test(arguments: ["zh-Hans", "en"])
    func mainPanelViewLaysOutInBothLocales(localeIdentifier: String) {
        let services = TestServices()
        let view = MainPanelView().testServices(services, locale: localeIdentifier)

        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 760, height: 520)
        host.layoutSubtreeIfNeeded()
        #expect(host.frame.size.width == 760)
        #expect(host.frame.size.height == 520)
    }
}
