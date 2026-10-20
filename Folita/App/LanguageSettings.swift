import Foundation
import Observation

/// 应用程序支持的界面语言选项。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system:
            "System Default"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        }
    }
}

/// 集中管理语言设置，负责读取持久化配置、跟随系统语言探测及向 SwiftUI 视图树分发有效 Locale。
@MainActor
@Observable
final class LanguageSettings {
    static let shared = LanguageSettings()

    static let userDefaultsKey = "FolitaAppLanguage"

    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]

    var selectedLanguage: AppLanguage {
        didSet {
            userDefaults.set(selectedLanguage.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider

        if let raw = userDefaults.string(forKey: Self.userDefaultsKey),
           let language = AppLanguage(rawValue: raw) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
    }

    /// 当前实际生效的语言。若为跟随系统，则动态解析系统偏好。
    var effectiveLanguage: AppLanguage {
        switch selectedLanguage {
        case .system:
            return Self.resolveSystemLanguage(preferredLanguages: preferredLanguagesProvider())
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        }
    }

    /// 供 SwiftUI `.environment(\.locale, ...)` 使用的 Locale。
    var effectiveLocale: Locale {
        Locale(identifier: effectiveLanguage.rawValue)
    }

    /// 根据系统首选语言列表匹配支持的语言（en 或 zh-Hans）。
    static func resolveSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let lower = identifier.lowercased()
            if lower.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if lower.hasPrefix("en") {
                return .english
            }
        }
        return .english
    }
}
