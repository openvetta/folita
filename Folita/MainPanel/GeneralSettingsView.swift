import SwiftUI

/// 通用设置页面：提供语言切换及后续通用偏好项。
struct GeneralSettingsView: View {
    @Environment(LanguageSettings.self) private var languageSettings

    var body: some View {
        @Bindable var settings = languageSettings
        Form {
            Section {
                Picker("Language", selection: $settings.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Language")
            } footer: {
                Text(footerText)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var footerText: LocalizedStringResource {
        switch languageSettings.selectedLanguage {
        case .system:
            "Follow system language settings by default."
        case .english, .simplifiedChinese:
            "Choose your preferred display language for Folita."
        }
    }
}
