import AppKit
import SwiftUI

/// 通用设置页面：语言、开机自启与自动粘贴。
struct GeneralSettingsView: View {
    @Environment(LanguageSettings.self) private var languageSettings
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @Environment(PasteSettings.self) private var pasteSettings
    @Environment(\.accessibilityAccess) private var accessibility

    @State private var isAccessibilityTrusted = false

    var body: some View {
        @Bindable var settings = languageSettings
        @Bindable var paste = pasteSettings
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

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
            } header: {
                Text("Startup")
            } footer: {
                if let error = launchAtLogin.lastError {
                    Text(verbatim: error)
                        .foregroundStyle(.red)
                } else if launchAtLogin.needsApproval {
                    Text("Approve Folita under Login Items in System Settings.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Paste automatically", isOn: $paste.autoPaste)
                if paste.autoPaste {
                    LabeledContent {
                        if isAccessibilityTrusted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Open System Settings", action: grantAccessibility)
                        }
                    } label: {
                        Text("Permission")
                    }
                }
            } header: {
                Text("Paste")
            } footer: {
                Text("Selected items are pasted into the app you were using. Without permission they are only copied, and you press ⌘V to paste.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshStatus)
        // 用户去系统设置授权后切回来时刷新状态。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
        }
    }

    private var footerText: LocalizedStringResource {
        switch languageSettings.selectedLanguage {
        case .system:
            "Follow system language settings by default."
        case .english, .simplifiedChinese:
            "Choose your preferred display language for Folita."
        }
    }

    private func refreshStatus() {
        isAccessibilityTrusted = accessibility.isTrusted()
        launchAtLogin.refresh()
    }

    private func grantAccessibility() {
        accessibility.requestAccess()
        if let url = PanelNotice.accessibilityNeeded.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}

extension EnvironmentValues {
    /// 测试中替换为假的授权状态。
    @Entry var accessibilityAccess: AccessibilityAccess = .system
}
