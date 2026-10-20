import SwiftUI

/// 面板标题下方的权限提示：点击卡片前往系统设置修复，右上角关闭。
struct PanelNoticeBanner: View {
    let notice: PanelNotice
    let action: () -> Void
    var onDismiss: () -> Void = {}

    var body: some View {
        if let content {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: content.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(content.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 28)
                }
                .padding(12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .padding(6)
                .help(Text("Not Now"))
                .accessibilityLabel(Text("Not Now"))
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }

    private var content: (symbol: String, title: LocalizedStringResource, message: LocalizedStringResource)? {
        switch notice {
        case .none:
            nil
        case .accessibilityNeeded:
            (
                "hand.raised",
                "Auto-paste needs permission",
                "Selected items are copied — press ⌘V to paste. Click to grant permission in System Settings."
            )
        case .pasteboardDenied:
            (
                "exclamationmark.triangle",
                "Clipboard access is denied",
                "Folita can't record new copies. Click to allow clipboard access in System Settings."
            )
        }
    }
}
