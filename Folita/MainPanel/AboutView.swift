import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(verbatim: "Folita")
                .font(.system(size: 26, weight: .semibold))
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack(spacing: 16) {
                Link(destination: AppInfo.repositoryURL) {
                    Text("Source Code")
                }
                Link(destination: AppInfo.licenseURL) {
                    Text("MIT License")
                }
            }
            Text(verbatim: "© 2026 \(AppInfo.copyrightHolder)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
