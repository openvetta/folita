import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 隐私设置：暂停记录与忽略的应用。
struct PrivacySettingsView: View {
    @Environment(PrivacySettings.self) private var privacySettings

    var body: some View {
        @Bindable var privacy = privacySettings
        Form {
            Section {
                Toggle("Pause Recording", isOn: $privacy.isPaused)
            } header: {
                Text("Recording")
            } footer: {
                Text("Content that password managers mark as hidden or temporary is never recorded.")
                    .foregroundStyle(.secondary)
            }

            Section {
                if privacy.ignoredBundleIDs.isEmpty {
                    Text("No ignored apps")
                        .foregroundStyle(.secondary)
                }
                ForEach(privacy.ignoredBundleIDs, id: \.self) { bundleID in
                    IgnoredAppRow(bundleID: bundleID) {
                        privacy.unignore(bundleID: bundleID)
                    }
                }
                Button("Add App…", action: chooseApp)
            } header: {
                Text("Ignored Apps")
            } footer: {
                Text("Copies made in these apps are not recorded.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Self.bundleID(ofAppAt: url) {
                privacySettings.ignore(bundleID: bundleID)
            }
        }
    }

    static func bundleID(ofAppAt url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }
}

private struct IgnoredAppRow: View {
    let bundleID: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let icon = ClipPreviewImages.appIcon(bundleID: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: displayName)
                if displayName != bundleID {
                    Text(verbatim: bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(Text("Remove"))
            .accessibilityLabel(Text("Remove"))
        }
    }

    /// 已卸载的应用只能显示 bundle ID。
    private var displayName: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path(percentEncoded: false))
            .replacingOccurrences(of: ".app", with: "")
    }
}
